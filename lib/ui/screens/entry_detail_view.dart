import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
        Clipboard,
        ClipboardData,
        HardwareKeyboard,
        KeyDownEvent,
        KeyRepeatEvent,
        LogicalKeyboardKey;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:taul/core/constants.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';
import 'package:taul/core/rich_text_helper.dart';
import 'package:taul/ui/providers/color_providers.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/providers/tag_settings_providers.dart';
import 'package:taul/ui/widgets/master_password_recovery_dialog.dart';
import 'package:taul/ui/widgets/palette_picker.dart';


/// Result of the master password reveal dialog.
///
/// One of:
/// - [password]: user entered a master password
/// - [recoveryCompleted]: user completed recovery via backup codes
/// - [cancelled]: user dismissed the dialog
class _RevealDialogResult {
  final String? password;
  final bool recoveryCompleted;
  final bool cancelled;

  _RevealDialogResult._({
    this.password,
    this.recoveryCompleted = false,
    this.cancelled = false,
  });

  factory _RevealDialogResult.password(String pw) =>
      _RevealDialogResult._(password: pw);

  factory _RevealDialogResult.recovery() =>
      _RevealDialogResult._(recoveryCompleted: true);

  factory _RevealDialogResult.cancelled() =>
      _RevealDialogResult._(cancelled: true);
}

class EntryDetailView extends ConsumerStatefulWidget {
  final String entryId;

  const EntryDetailView({super.key, required this.entryId});

  @override
  ConsumerState<EntryDetailView> createState() => _EntryDetailViewState();
}

class _EntryDetailViewState extends ConsumerState<EntryDetailView>
    with WidgetsBindingObserver {
  // ── Controllers ────────────────────────────────────────────────────────
  late TextEditingController _titleCtrl;
  late TextEditingController _tagsCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _passwordCtrl;
  late TextEditingController _urlCtrl;
  late QuillController _quillCtrl;
  final _tagAddCtrl = TextEditingController();
  final _tagAddFocus = FocusNode();

  // ── State ──────────────────────────────────────────────────────────────
  bool _hasChanges = false;
  bool _isSaving = false;
  Entry? _cachedEntry;
  Uint8List? _cachedDek;
  List<String> _tags = [];
  EntryType? _selectedType;
  bool _showPassword = false;
  String? _revealedSecret;
  Timer? _hideTimer;

  // ── Lifecycle ──────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initControllers();

    final entry = _cachedEntry;
    if (entry != null &&
        entry.type == EntryType.credential &&
        entry.requiresAuth &&
        entry.encryptedSecret != null &&
        entry.cipherNonce != null &&
        entry.cipherTag != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoRevealOnOpen(entry);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSave();
    _titleCtrl.dispose();
    _tagsCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _urlCtrl.dispose();
    _tagAddCtrl.dispose();
    _tagAddFocus.dispose();
    _quillCtrl.removeListener(_onQuillChanged);
    _quillCtrl.dispose();
    _hideTimer?.cancel();
    if (_cachedDek != null) {
      ref.read(masterPasswordProvider.notifier).clearMasterPassword();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _autoSave();
    }
  }

  // ── Initialization ─────────────────────────────────────────────────────
  void _initControllers() {
    final entry =
        ref.read(entryDetailProvider(widget.entryId)).valueOrNull;
    _cachedEntry = entry;

    _titleCtrl = TextEditingController(text: entry?.title ?? '');
    _titleCtrl.addListener(_markChanged);

    _tags = entry != null ? List.from(entry.tags) : [];
    _tagsCtrl = TextEditingController(text: _tags.join(', '));
    _tagsCtrl.addListener(_markChanged);

    _usernameCtrl = TextEditingController(
      text: entry?.metadata['username'] ?? '',
    );
    _usernameCtrl.addListener(_markChanged);

    _passwordCtrl = TextEditingController(text: entry?.secret ?? '');
    _passwordCtrl.addListener(_markChanged);

    _urlCtrl = TextEditingController(
      text: entry?.metadata['url'] ?? '',
    );
    _urlCtrl.addListener(_markChanged);

    final doc = entry != null
        ? RichTextHelper.getDocument(entry.content)
        : Document();
    _quillCtrl = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _quillCtrl.addListener(_onQuillChanged);

    _selectedType = entry?.type;
  }

  void _onQuillChanged() {
    _markChanged();
  }

  void _markChanged() {
    _hasChanges = true;
  }

  // ── Auto-save ──────────────────────────────────────────────────────────
  Future<void> _autoSave() async {
    if (!_hasChanges || _isSaving || !mounted) return;
    final entry = _cachedEntry;
    if (entry == null) return;

    _isSaving = true;
    try {
      final contentJson =
          RichTextHelper.documentToJson(_quillCtrl.document);
      final newSecret = _passwordCtrl.text;
      final originalSecret = entry.secret ?? '';

      Map<String, String>? newMetadata;
      if (entry.type == EntryType.credential) {
        newMetadata = {
          'username': _usernameCtrl.text,
          if (_urlCtrl.text.isNotEmpty) 'url': _urlCtrl.text,
        };
      }

      if (!mounted) return;

      if (entry.type == EntryType.credential &&
          entry.requiresAuth &&
          newSecret != originalSecret &&
          _cachedDek != null) {
        // Re-encrypt with cached DEK
        final auth = ref.read(entryAuthServiceProvider);
        final encrypted = await auth.encryptSecret(
          plaintext: newSecret,
          masterKey: _cachedDek!,
        );
        if (!mounted) return;
        await ref.read(updateEntryProvider).call(
              entry,
              title: _titleCtrl.text,
              content: contentJson,
              tags: _tags,
              metadata: newMetadata,
              secret: newSecret,
              encryptedSecret: encrypted.ciphertextHex,
              cipherNonce: encrypted.nonceHex,
              cipherTag: encrypted.tagHex,
              type: _selectedType ?? entry.type,
            );
      } else {
        if (!mounted) return;
        await ref.read(updateEntryProvider).call(
              entry,
              title: _titleCtrl.text,
              content: contentJson,
              tags: _tags,
              metadata: newMetadata,
              secret: entry.type == EntryType.credential ? newSecret : null,
              type: _selectedType ?? entry.type,
            );
      }

      _hasChanges = false;

      if (!mounted) return;
      ref.invalidate(entryDetailProvider(widget.entryId));
      ref.invalidate(entryListProvider);
      ref.invalidate(tagSettingsListProvider);
      ref.invalidate(tagSettingsMapProvider);
    } catch (e) {
      Logger().e('auto-save failed', error: e);
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _goBack() async {
    await _autoSave();
    if (mounted) context.pop();
  }

  // ── Tag helpers ────────────────────────────────────────────────────────
  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
      _hasChanges = true;
    });
  }

  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty || _tags.contains(trimmed)) return;
    setState(() {
      _tags.add(trimmed);
      _tagAddCtrl.clear();
      _hasChanges = true;
    });
    _tagAddFocus.requestFocus();
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final entryAsync = ref.watch(entryDetailProvider(widget.entryId));
    final entryIds = ref.watch(entryIdListProvider);
    final currentIndex = entryIds.indexOf(widget.entryId);
    final hasPrevious = currentIndex > 0;
    final hasNext = currentIndex < entryIds.length - 1;

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyRepeatEvent) return KeyEventResult.ignored;
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final ctrl = HardwareKeyboard.instance.isLogicalKeyPressed(
              LogicalKeyboardKey.controlLeft,
            ) ||
            HardwareKeyboard.instance.isLogicalKeyPressed(
              LogicalKeyboardKey.controlRight,
            );

        // Ctrl+E → focus title
        if (ctrl && event.logicalKey == LogicalKeyboardKey.keyE) {
          _titleCtrl.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _titleCtrl.text.length,
          );
          return KeyEventResult.handled;
        }

        // Delete → eliminar entrada
        if (event.logicalKey == LogicalKeyboardKey.delete) {
          _confirmDelete();
          return KeyEventResult.handled;
        }

        // Ctrl+Left → entrada anterior
        if (ctrl && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _goToAdjacent(entryIds, currentIndex, context, -1);
          return KeyEventResult.handled;
        }

        // Ctrl+Right → entrada siguiente
        if (ctrl && event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _goToAdjacent(entryIds, currentIndex, context, 1);
          return KeyEventResult.handled;
        }

        // Ctrl+Tab → siguiente, Ctrl+Shift+Tab → anterior
        if (ctrl && event.logicalKey == LogicalKeyboardKey.tab) {
          final shift = HardwareKeyboard.instance.isLogicalKeyPressed(
                LogicalKeyboardKey.shiftLeft,
              ) ||
              HardwareKeyboard.instance.isLogicalKeyPressed(
                LogicalKeyboardKey.shiftRight,
              );
          _goToAdjacent(entryIds, currentIndex, context, shift ? -1 : 1);
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Volver',
            onPressed: _goBack,
          ),
          title: Text(entryAsync.valueOrNull?.type.label ?? 'Entrada'),
          actions: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Anterior',
              onPressed: hasPrevious
                  ? () => context.go(
                      '/entry/${entryIds[currentIndex - 1]}')
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Siguiente',
              onPressed: hasNext
                  ? () =>
                      context.go('/entry/${entryIds[currentIndex + 1]}')
                  : null,
            ),
            const SizedBox(width: 8),
            if (entryAsync.valueOrNull?.type != EntryType.credential)
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copiar título y contenido',
                onPressed: () {
                  final entry = entryAsync.valueOrNull;
                  if (entry != null) {
                    final plainContent =
                        RichTextHelper.documentToPlainText(
                      RichTextHelper.getDocument(entry.content),
                    );
                    final text = '${entry.title}\n\n$plainContent';
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Contenido copiado'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDelete,
            ),
          ],
        ),
        body: entryAsync.when(
          data: (entry) {
            _cachedEntry = entry;
            // Re-sync controllers if entry loaded asynchronously
            if (_tags.isEmpty && entry.tags.isNotEmpty) {
              _tags = List.from(entry.tags);
            }
            if (_selectedType == null) {
              _selectedType = entry.type;
            }
            final displayColor =
                ref.watch(entryDisplayColorProvider(entry.id));
            final theme = Theme.of(context);

            final content = entry.type == EntryType.credential
                ? _buildCredentialContent(theme)
                : _buildNoteContent(theme);

            return Card(
              margin: EdgeInsets.zero,
              color: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(
                      color: displayColor?.withValues(alpha: 0.15) ??
                          theme.colorScheme.surface,
                    ),
                  ),
                  if (displayColor != null)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 6,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              displayColor,
                              displayColor.withValues(alpha: 0.4),
                            ],
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: content,
                  ),
                ],
              ),
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  static void _goToAdjacent(
    List<String> ids,
    int currentIndex,
    BuildContext context,
    int direction,
  ) {
    final target = currentIndex + direction;
    if (target < 0 || target >= ids.length) return;
    context.go('/entry/${ids[target]}');
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar entrada'),
        content: const Text(
          '¿Mover a la papelera? Podés restaurarla después.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _autoSave();
              if (!mounted) return;
              Navigator.pop(context);
              await ref.read(deleteEntryProvider).call(widget.entryId);
              ref.invalidate(entryListProvider);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // ── Note Content ───────────────────────────────────────────────────────
  Widget _buildNoteContent(ThemeData theme) {
    final entry = _cachedEntry;
    if (entry == null) return const SizedBox.shrink();

    final isWide = MediaQuery.of(context).size.width >= Breakpoints.tablet;
    final isCompleted = entry.completedAt != null;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type chip + complete button
          Row(
            children: [
              Chip(
                label: Text(
                  (_selectedType ?? entry.type).label,
                  style: const TextStyle(fontSize: 12),
                ),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 0,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              if (isCompleted) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 28,
                  child: TextButton.icon(
                    onPressed: () async {
                      await ref
                          .read(markAsCompletedProvider)
                          .call(entry);
                      ref.invalidate(
                        entryDetailProvider(widget.entryId),
                      );
                      ref.invalidate(filteredEntriesProvider);
                    },
                    icon: const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.green,
                    ),
                    label: const Text(
                      'Completada',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                      ),
                      foregroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
              if (entry.type == EntryType.task && !isCompleted) ...[
                const SizedBox(width: 8),
                SizedBox(
                  height: 28,
                  child: TextButton.icon(
                    onPressed: () async {
                      await ref
                          .read(markAsCompletedProvider)
                          .call(entry);
                      ref.invalidate(
                        entryDetailProvider(widget.entryId),
                      );
                      ref.invalidate(filteredEntriesProvider);
                    },
                    icon: const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                    ),
                    label: const Text(
                      'Completar',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Title — editable TextField styled as headlineSmall
          TextField(
            controller: _titleCtrl,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontStyle: isCompleted ? FontStyle.italic : null,
              decoration: isCompleted
                  ? TextDecoration.lineThrough
                  : null,
              color: isCompleted
                  ? theme.colorScheme.onSurfaceVariant
                  : null,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
            maxLines: 1,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _markChanged(),
          ),
          const SizedBox(height: 16),

           // Content — always-editable QuillEditor with compact toolbar
           QuillSimpleToolbar(
             controller: _quillCtrl,
             config: QuillSimpleToolbarConfig(
               showBackgroundColorButton: false,
               showColorButton: false,
               showFontFamily: false,
               showFontSize: false,
               showSubscript: false,
               showSuperscript: false,
               showHeaderStyle: false,
               showListCheck: false,
               showListBullets: true,
               showListNumbers: true,
               showBoldButton: true,
               showItalicButton: true,
               showUnderLineButton: true,
               showStrikeThrough: true,
               showQuote: false,
               showIndent: false,
               showAlignmentButtons: false,
               showLink: false,
               showSearchButton: false,
               showClearFormat: false,
               showDirection: false,
               showUndo: false,
               showRedo: false,
               showCodeBlock: false,
               multiRowsDisplay: true,
               decoration: BoxDecoration(
                 color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                 borderRadius: BorderRadius.circular(8),
               ),
             ),
           ),
           const SizedBox(height: 8),
           QuillEditor.basic(
             controller: _quillCtrl,
             config: const QuillEditorConfig(
               scrollable: false,
               padding: EdgeInsets.zero,
               placeholder: 'Escribí algo...',
             ),
           ),

          // Tags — editable chips + inline add
          const SizedBox(height: 16),
          _buildTagInput(),
          const SizedBox(height: 24),

          // Timestamps
          Text(
            'Creado: ${_formatDate(entry.createdAt)}',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            'Actualizado: ${_formatDate(entry.updatedAt)}',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            'Versión: ${entry.version}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  // ── Tag Input ──────────────────────────────────────────────────────────
  Widget _buildTagInput() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            ..._tags.map((t) {
              final tagColor = ref.watch(
                tagColorForEntryProvider(
                  (_cachedEntry!.id, t),
                ),
              );
              return GestureDetector(
                onLongPress: () => _showPalettePicker(
                  context,
                  ref,
                  _cachedEntry!,
                  t,
                ),
                child: InputChip(
                  label: Text(
                    t,
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: tagColor,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onDeleted: () => _removeTag(t),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onPressed: () {
                    ref.read(selectedTagFilterProvider.notifier).state = t;
                    context.pop();
                  },
                ),
              );
            }),
            // Inline add tag field
            SizedBox(
              width: 120,
              height: 32,
              child: TextField(
                controller: _tagAddCtrl,
                focusNode: _tagAddFocus,
                style: theme.textTheme.bodySmall,
                decoration: InputDecoration(
                  hintText: '+ tag',
                  hintStyle: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  isDense: true,
                ),
                onSubmitted: _addTag,
                textInputAction: TextInputAction.done,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Credential Content ─────────────────────────────────────────────────
  Widget _buildCredentialContent(ThemeData theme) {
    final entry = _cachedEntry;
    if (entry == null) return const SizedBox.shrink();

    final isWide = MediaQuery.of(context).size.width >= Breakpoints.tablet;
    final displayedSecret = entry.requiresAuth
        ? (_revealedSecret ?? '')
        : (_passwordCtrl.text);

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + lock icon
          Center(
            child: Column(
              children: [
                const Icon(Icons.lock, size: 40, color: Colors.amber),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleCtrl,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  maxLines: 1,
                  onChanged: (_) => _markChanged(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Username field
          _buildEditableField(
            icon: Icons.person,
            label: 'Usuario',
            controller: _usernameCtrl,
          ),
          const SizedBox(height: 12),

          // Password field (editable)
          _buildPasswordField(theme, displayedSecret, entry),
          if (entry.requiresAuth) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _revealProtectedSecret(),
              icon: const Icon(Icons.lock_open),
              label: Text(
                _revealedSecret == null
                    ? 'Revelar Secreto'
                    : 'Revelar de Nuevo',
              ),
            ),
          ],
          const SizedBox(height: 12),

          // URL field
          if (_urlCtrl.text.isNotEmpty || _urlCtrl.text.isNotEmpty)
            _buildEditableField(
              icon: Icons.link,
              label: 'URL',
              controller: _urlCtrl,
            ),
          if (_urlCtrl.text.isNotEmpty || _urlCtrl.text.isNotEmpty)
            const SizedBox(height: 12),

          // Tags
          _buildTagInput(),
          const SizedBox(height: 24),

          // Timestamps
          Text(
            'Creado: ${_formatDate(entry.createdAt)}',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            'Actualizado: ${_formatDate(entry.updatedAt)}',
            style: theme.textTheme.bodySmall,
          ),
          Text(
            'Versión: ${entry.version}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    bool obscure = false,
    VoidCallback? onToggleObscure,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  obscure
                      ? Text(
                          '?' * (controller.text.length.clamp(6, 20)),
                          style: const TextStyle(
                            fontSize: 15,
                            fontFamily: 'monospace',
                          ),
                        )
                      : TextField(
                          controller: controller,
                          style: const TextStyle(
                            fontSize: 15,
                            fontFamily: 'monospace',
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          onChanged: (_) => _markChanged(),
                        ),
                ],
              ),
            ),
            if (controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Copiar',
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: controller.text)),
              ),
            if (onToggleObscure != null)
              IconButton(
                icon: Icon(
                  obscure ? Icons.visibility : Icons.visibility_off,
                  size: 18,
                ),
                tooltip: obscure ? 'Mostrar' : 'Ocultar',
                onPressed: onToggleObscure,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField(
    ThemeData theme,
    String displayedSecret,
    Entry entry,
  ) {
    final isObscured = !_showPassword && _revealedSecret == null;
    return _buildEditableField(
      icon: Icons.key,
      label: 'Contraseña',
      controller: _passwordCtrl,
      obscure: isObscured,
      onToggleObscure: () =>
          setState(() => _showPassword = !_showPassword),
    );
  }

  // ── Protected credential reveal ────────────────────────────────────────
  Future<void> _autoRevealOnOpen(Entry entry) async {
    await _revealProtectedSecret();
  }

  Future<void> _revealProtectedSecret() async {
    final entry = _cachedEntry;
    if (entry == null || !entry.requiresAuth) return;

    // Quick-add credentials (no encryption)
    if (entry.encryptedSecret == null ||
        entry.cipherNonce == null ||
        entry.cipherTag == null) {
      if (entry.secret != null) {
        setState(() => _revealedSecret = entry.secret);
        _passwordCtrl.text = entry.secret!;
        _passwordCtrl.selection = TextSelection.collapsed(
          offset: _passwordCtrl.text.length,
        );
        _hideTimer?.cancel();
        _hideTimer = Timer(const Duration(seconds: 30), () {
          if (mounted) setState(() => _revealedSecret = null);
        });
      }
      return;
    }

    final auth = ref.read(entryAuthServiceProvider);
    final masterKeyNotifier = ref.read(masterPasswordProvider.notifier);
    Uint8List? key = masterKeyNotifier.cachedKey;

    if (key == null) {
      final store = ref.read(masterPasswordStoreProvider);
      final config = await store.readFull();

      if (config == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Contraseña maestra no configurada. '
                'Configurala desde Ajustes.',
              ),
            ),
          );
        }
        return;
      }

      final salt = auth.hexToBytes(config.saltHex);
      final result = await _showMasterPasswordDialog(
        entry: entry,
        verify: (password) async {
          return auth.verifyMasterPassword(
            password: password,
            salt: salt,
            expectedHashHex: config.hashHex,
          );
        },
      );
      if (result == null || result.cancelled || !mounted) return;

      if (result.recoveryCompleted) {
        key = masterKeyNotifier.cachedKey;
        if (key == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Recuperación completada pero no se pudo cargar la '
                  'clave. Intentá revelar el secreto de nuevo.',
                ),
              ),
            );
          }
          return;
        }
      } else {
        final password = result.password!;
        if (config.encryptedStorageKeyHex != null &&
            config.encryptedStorageKeyHex!.isNotEmpty) {
          final kek = await auth.deriveMasterKey(
            password: password,
            salt: salt,
          );
          key = await auth.unwrapStorageKey(
            payload: EncryptionPayload(
              ciphertextHex: config.encryptedStorageKeyHex!,
              nonceHex: config.encryptedStorageKeyNonceHex ?? '',
              tagHex: config.encryptedStorageKeyTagHex ?? '',
            ),
            kek: kek,
          );
        } else {
          key = await auth.deriveMasterKey(password: password, salt: salt);
        }
        masterKeyNotifier.setMasterPassword(key);
      }
    }

    // Cache the DEK for re-encryption on save
    _cachedDek = key;

    try {
      final plaintext = await auth.decryptSecret(
        payload: EncryptionPayload(
          ciphertextHex: entry.encryptedSecret!,
          nonceHex: entry.cipherNonce!,
          tagHex: entry.cipherTag!,
        ),
        masterKey: key,
      );

      if (!mounted) return;
      setState(() {
        _revealedSecret = plaintext;
        _showPassword = false;
      });
      _passwordCtrl.text = plaintext;

      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(seconds: 30), () {
        if (!mounted) return;
        setState(() => _revealedSecret = null);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al descifrar: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<_RevealDialogResult?> _showMasterPasswordDialog({
    required Entry entry,
    required Future<bool> Function(String password) verify,
  }) async {
    final hint = await ref.read(masterPasswordHintProvider.future);
    final ctrl = TextEditingController();
    String? error;
    var obscurePassword = true;
    var showHint = false;
    var loading = false;

    Future<void> verifyAndPop(
      BuildContext ctx,
      void Function(void Function()) setLocalState,
    ) async {
      final password = ctrl.text;
      if (password.isEmpty) {
        setLocalState(() => error = 'Ingresá tu contraseña');
        return;
      }
      setLocalState(() {
        loading = true;
        error = null;
      });
      try {
        final isValid = await verify(password);
        if (isValid) {
          Navigator.pop(ctx, _RevealDialogResult.password(password));
        } else {
          setLocalState(() {
            loading = false;
            error = 'Contraseña incorrecta';
          });
        }
      } catch (_) {
        setLocalState(() {
          loading = false;
          error = 'Error al verificar';
        });
      }
    }

    final result = await showDialog<_RevealDialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Contraseña Maestra'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                obscureText: obscurePassword,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: loading
                    ? null
                    : (_) => verifyAndPop(ctx, setLocalState),
                decoration: InputDecoration(
                  labelText: 'Ingresá tu contraseña maestra',
                  errorText: error,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    onPressed: () =>
                        setLocalState(() => obscurePassword = !obscurePassword),
                  ),
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 4),
                TextButton.icon(
                  icon: Icon(
                    showHint ? Icons.visibility_off : Icons.visibility,
                    size: 16,
                  ),
                  label: Text(showHint ? 'Ocultar pista' : 'Mostrar pista'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () =>
                      setLocalState(() => showHint = !showHint),
                ),
                if (showHint) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Theme.of(ctx).colorScheme.tertiary,
                      ),
                    ),
                    child: Text(
                      'Pista: $hint',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 4),
              TextButton(
                onPressed: loading
                    ? null
                    : () async {
                        final recoveryResult =
                            await Navigator.push<RecoveryResult>(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) =>
                                const MasterPasswordRecoveryDialog(),
                            fullscreenDialog: true,
                          ),
                        );
                        if (recoveryResult != null &&
                            recoveryResult.success) {
                          if (ctx.mounted) {
                            Navigator.pop(
                              ctx,
                              _RevealDialogResult.recovery(),
                            );
                          }
                        }
                      },
                child: const Text(
                  '¿Olvidaste tu contraseña maestra?',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: loading
                  ? null
                  : () => Navigator.pop(
                      ctx,
                      _RevealDialogResult.cancelled(),
                    ),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: loading
                  ? null
                  : () => verifyAndPop(ctx, setLocalState),
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Aceptar'),
            ),
          ],
        ),
      ),
    );

    return result;
  }

  // ── Shared helpers ─────────────────────────────────────────────────────
  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showPalettePicker(
    BuildContext context,
    WidgetRef ref,
    Entry entry,
    String tagName,
  ) async {
    final tagMap = ref.watch(tagSettingsMapProvider);
    final currentHex = tagMap[tagName.toLowerCase()]?.color;
    final initialColor = currentHex != null && currentHex.isNotEmpty
        ? parseHex(currentHex)
        : null;

    final selectedHex = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Color for "$tagName"'),
        content: PalettePicker(
          initialColor: initialColor,
          onColorSelected: (hex) => Navigator.pop(ctx, hex),
        ),
      ),
    );

    if (selectedHex != null && context.mounted) {
      final existingIsSystem =
          tagMap[tagName.toLowerCase()]?.isSystem ?? false;
      await ref
          .read(saveTagSettingProvider)
          .call(
            tagName,
            color: selectedHex.isEmpty ? null : selectedHex,
            isSystem: existingIsSystem,
          );
      ref.invalidate(tagSettingsListProvider);
      ref.invalidate(tagSettingsMapProvider);
    }
  }
}
