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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taul/core/constants.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';
import 'package:taul/core/rich_text_helper.dart';
import 'package:taul/ui/providers/color_providers.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/providers/tag_settings_providers.dart';
import 'package:taul/ui/screens/credential_form_sheet.dart';
import 'package:taul/ui/widgets/rich_text_display.dart';
import 'package:taul/ui/widgets/rich_text_editor.dart';
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

class EntryDetailView extends ConsumerWidget {
  final String entryId;

  const EntryDetailView({super.key, required this.entryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entryAsync = ref.watch(entryDetailProvider(entryId));
    final entryIds = ref.watch(entryIdListProvider);
    final currentIndex = entryIds.indexOf(entryId);
    final hasPrevious = currentIndex > 0;
    final hasNext = currentIndex < entryIds.length - 1;

    return Focus(
      autofocus: true,
      onFocusChange: (f) => debugPrint(
        '[EDV] EntryDetailView focus: $f entryId=$entryId',
      ),
      onKeyEvent: (node, event) {
        // DEBUG: log every key event
        debugPrint(
          '[EDV] keyEvent: ${event.runtimeType} logicalKey=${event.logicalKey} '
          'physicalKey=${event.physicalKey}',
        );

        if (event is KeyRepeatEvent) return KeyEventResult.ignored;
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final ctrl =
            HardwareKeyboard.instance
                    .isLogicalKeyPressed(LogicalKeyboardKey.controlLeft) ||
                HardwareKeyboard.instance
                    .isLogicalKeyPressed(LogicalKeyboardKey.controlRight);

        // Ctrl+E → editar entrada
        if (ctrl && event.logicalKey == LogicalKeyboardKey.keyE) {
          debugPrint('[EDV] Ctrl+E → edit entryId=$entryId');
          _showEdit(context, ref);
          return KeyEventResult.handled;
        }

        // Delete → eliminar entrada
        if (event.logicalKey == LogicalKeyboardKey.delete) {
          debugPrint('[EDV] Delete → trash entryId=$entryId');
          _confirmDelete(context, ref);
          return KeyEventResult.handled;
        }

        // Ctrl+Left → entrada anterior
        if (ctrl && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          debugPrint('[EDV] Ctrl+Left → previous from index=$currentIndex');
          _goToAdjacent(entryIds, currentIndex, context, -1);
          return KeyEventResult.handled;
        }

        // Ctrl+Right → entrada siguiente
        if (ctrl && event.logicalKey == LogicalKeyboardKey.arrowRight) {
          debugPrint('[EDV] Ctrl+Right → next from index=$currentIndex');
          _goToAdjacent(entryIds, currentIndex, context, 1);
          return KeyEventResult.handled;
        }

        // Ctrl+Tab → siguiente, Ctrl+Shift+Tab → anterior
        if (ctrl && event.logicalKey == LogicalKeyboardKey.tab) {
          final shift =
              HardwareKeyboard.instance
                      .isLogicalKeyPressed(LogicalKeyboardKey.shiftLeft) ||
                  HardwareKeyboard.instance
                      .isLogicalKeyPressed(LogicalKeyboardKey.shiftRight);
          debugPrint('[EDV] Ctrl+Tab shift=$shift from index=$currentIndex');
          _goToAdjacent(entryIds, currentIndex, context, shift ? -1 : 1);
          return KeyEventResult.handled;
        }

        debugPrint(
          '[EDV] unhandled: ctrl=$ctrl key=${event.logicalKey}',
        );
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Volver',
            onPressed: () => context.pop(),
          ),
          title: Text(entryAsync.valueOrNull?.type.label ?? 'Entrada'),
          actions: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Anterior',
              onPressed: hasPrevious
                  ? () => context.go('/entry/${entryIds[currentIndex - 1]}')
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Siguiente',
              onPressed: hasNext
                  ? () => context.go('/entry/${entryIds[currentIndex + 1]}')
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
                    final plainContent = RichTextHelper.documentToPlainText(
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
              icon: const Icon(Icons.edit),
              onPressed: () => _showEdit(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
        body: entryAsync.when(
        data: (entry) {
          final displayColor = ref.watch(entryDisplayColorProvider(entry.id));
          final theme = Theme.of(context);
          final content = entry.type == EntryType.credential
              ? _CredentialContent(entry: entry)
              : _NoteContent(entry: entry);
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
                // Force full width even when content text is short,
                // so the background ColoredBox fills the whole card.
                SizedBox(width: double.infinity, child: content),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
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

  void _showEdit(BuildContext context, WidgetRef ref) {
    final entry = ref.read(entryDetailProvider(entryId)).valueOrNull;
    if (entry == null) return;

    if (entry.type == EntryType.credential) {
      _showCredentialEdit(context, entry);
    } else {
      _showNoteEdit(context, ref, entry);
    }
  }

  IconData _iconForType(EntryType type) {
    return switch (type) {
      EntryType.note => Icons.description,
      EntryType.idea => Icons.lightbulb,
      EntryType.glossary => Icons.book,
      EntryType.credential => Icons.lock,
      EntryType.task => Icons.check_circle_outline,
    };
  }

  String _labelForType(EntryType type) {
    return switch (type) {
      EntryType.note => 'Nota',
      EntryType.idea => 'Idea',
      EntryType.glossary => 'Glosario',
      EntryType.credential => 'Credencial',
      EntryType.task => 'Tarea',
    };
  }

  void _showNoteEdit(BuildContext context, WidgetRef ref, Entry entry) {
    final titleCtrl = TextEditingController(text: entry.title);
    final tagsCtrl = TextEditingController(text: entry.tags.join(', '));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        var selectedType = entry.type;
        var isSaving = false;
        var richContent = entry.content;

        return StatefulBuilder(
          builder: (context, setLocalState) => Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.edit_note, size: 20),
                    const SizedBox(width: 8),
                    Text('Editar entrada', style: Theme.of(ctx).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                RichTextEditor(
                  initialContent: entry.content,
                  onChanged: (v) => setLocalState(() => richContent = v),
                ),
                const SizedBox(height: 12),
                _TagsAutocompleteField(
                  controller: tagsCtrl,
                  ref: ref,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Tipo:', style: Theme.of(ctx).textTheme.bodySmall),
                    const SizedBox(width: 8),
                    PopupMenuButton<EntryType>(
                      onSelected: (t) => setLocalState(() => selectedType = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_iconForType(selectedType), size: 14),
                            const SizedBox(width: 4),
                            Text(_labelForType(selectedType), style: const TextStyle(fontSize: 11)),
                            const SizedBox(width: 2),
                            Icon(Icons.arrow_drop_down, size: 14, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                          ],
                        ),
                      ),
                      itemBuilder: (_) => EntryType.values
                          .where((t) => t != EntryType.credential)
                          .map(
                            (t) => PopupMenuItem(
                              value: t,
                              child: ListTile(
                                dense: true,
                                leading: Icon(_iconForType(t), size: 18),
                                title: Text(_labelForType(t), style: const TextStyle(fontSize: 13)),
                                trailing: selectedType == t
                                    ? Icon(Icons.check, size: 16, color: Theme.of(ctx).colorScheme.primary)
                                    : null,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isSaving ? null : () => Navigator.pop(ctx),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              setLocalState(() => isSaving = true);
                              try {
                                // Extraer -#tag del contenido rich text
                                final plainText = RichTextHelper.documentToPlainText(
                                  RichTextHelper.getDocument(richContent),
                                );
                                final extracted = RichTextHelper.extractTags(plainText);
                                final contentTags = extracted.tags;
                                final content = RichTextHelper.stripTagsFromContent(
                                  richContent,
                                  contentTags,
                                );

                                // Tags manuales (campo separado por coma)
                                final manualTags = tagsCtrl.text
                                    .split(',')
                                    .map((t) => t.trim())
                                    .where((t) => t.isNotEmpty)
                                    .toList();

                                // Merge sin duplicados
                                final tags = {...manualTags, ...contentTags}.toList();

                                await ref.read(updateEntryProvider).call(
                                  entry,
                                  title: titleCtrl.text,
                                  content: content,
                                  tags: tags,
                                  type: selectedType,
                                );
                                ref.invalidate(entryDetailProvider(entryId));
                                ref.invalidate(entryListProvider);
                                if (ctx.mounted) Navigator.pop(ctx);
                              } catch (e) {
                                setLocalState(() => isSaving = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text('Error al guardar: $e')),
                                  );
                                }
                              }
                            },
                      child: Text(isSaving ? 'Guardando...' : 'Guardar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCredentialEdit(BuildContext context, Entry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CredentialFormSheet(entry: entry),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar entrada'),
        content: const Text('¿Mover a la papelera? Podés restaurarla después.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.pop(context);
              await ref.read(deleteEntryProvider).call(entryId);
              ref.invalidate(entryListProvider);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

class _NoteContent extends ConsumerWidget {
  final Entry entry;
  const _NoteContent({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= Breakpoints.tablet;

    final body = SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Chip(
            label: Text(entry.type.label, style: const TextStyle(fontSize: 12)),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          const SizedBox(height: 8),
          entry.title.isNotEmpty
              ? SelectableText(entry.title,
                  style: theme.textTheme.headlineSmall)
              : Text('(sin título)',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
          const SizedBox(height: 16),
          RichTextDisplay(content: entry.content),
          if (entry.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 6, children: entry.tags.map((t) {
              final tagColor = ref.watch(
                tagColorForEntryProvider((entry.id, t)),
              );
              return GestureDetector(
                onLongPress: () => _showPalettePicker(context, ref, entry, t),
                child: ActionChip(
                  label: Text(t, style: const TextStyle(fontSize: 12)),
                  backgroundColor: tagColor,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onPressed: () {
                    ref.read(selectedTagFilterProvider.notifier).state = t;
                    context.pop();
                  },
                ),
              );
            }).toList()),
          ],
          const SizedBox(height: 24),
          Text('Creado: ${_formatDate(entry.createdAt)}', style: theme.textTheme.bodySmall),
          Text('Actualizado: ${_formatDate(entry.updatedAt)}', style: theme.textTheme.bodySmall),
          Text('Versión: ${entry.version}', style: theme.textTheme.bodySmall),
        ],
      ),
    );

    return body;
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showPalettePicker(BuildContext context, WidgetRef ref, Entry entry, String tagName) async {
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
      await ref.read(saveTagSettingProvider).call(
        tagName,
        color: selectedHex.isEmpty ? null : selectedHex,
        isSystem: existingIsSystem,
      );
      ref.invalidate(tagSettingsListProvider);
    }
  }
}

class _CredentialContent extends ConsumerStatefulWidget {
  final Entry entry;
  const _CredentialContent({required this.entry});

  @override
  ConsumerState<_CredentialContent> createState() => _CredentialContentState();
}

class _CredentialContentState extends ConsumerState<_CredentialContent> {
  bool _showPassword = false;
  String? _revealedSecret;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;
    final username = entry.metadata['username'] ?? '';
    final url = entry.metadata['url'] ?? '';
    final displayedSecret = entry.requiresAuth ? (_revealedSecret ?? '') : (entry.secret ?? '');
    final isWide = MediaQuery.of(context).size.width >= Breakpoints.tablet;

    final body = SingleChildScrollView(
      padding: EdgeInsets.all(isWide ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                const Icon(Icons.lock, size: 40, color: Colors.amber),
                const SizedBox(height: 8),
          entry.title.isNotEmpty
              ? SelectableText(entry.title,
                  style: theme.textTheme.headlineSmall)
              : Text('(sin título)',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  )),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (username.isNotEmpty) ...[
            _fieldCard(
              icon: Icons.person,
              label: 'Usuario',
              value: username,
              onCopy: () => Clipboard.setData(ClipboardData(text: username)),
            ),
            const SizedBox(height: 12),
          ],
          _fieldCard(
            icon: Icons.key,
            label: 'Contraseña',
            value: displayedSecret,
            obscure: !_showPassword,
            onCopy: displayedSecret.isEmpty
                ? null
                : () => Clipboard.setData(ClipboardData(text: displayedSecret)),
            onToggleObscure: () => setState(() => _showPassword = !_showPassword),
          ),
          if (entry.requiresAuth) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _revealProtectedSecret,
              icon: const Icon(Icons.lock_open),
              label: Text(_revealedSecret == null ? 'Revelar Secreto' : 'Revelar de Nuevo'),
            ),
          ],
          const SizedBox(height: 12),
          if (url.isNotEmpty) ...[
            _fieldCard(
              icon: Icons.link,
              label: 'URL',
              value: url,
              onCopy: () => Clipboard.setData(ClipboardData(text: url)),
            ),
            const SizedBox(height: 12),
          ],
          if (entry.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, children: entry.tags.map((t) {
              final tagColor = ref.watch(
                tagColorForEntryProvider((entry.id, t)),
              );
              return GestureDetector(
                onLongPress: () => _showPalettePicker(context, ref, entry, t),
                child: ActionChip(
                  label: Text(t),
                  backgroundColor: tagColor,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onPressed: () {
                    ref.read(selectedTagFilterProvider.notifier).state = t;
                    context.pop();
                  },
                ),
              );
            }).toList()),
          ],
          const SizedBox(height: 24),
          Text('Creado: ${_formatDate(entry.createdAt)}', style: theme.textTheme.bodySmall),
          Text('Actualizado: ${_formatDate(entry.updatedAt)}', style: theme.textTheme.bodySmall),
          Text('Versión: ${entry.version}', style: theme.textTheme.bodySmall),
        ],
      ),
    );

    return body;
  }

  Future<void> _revealProtectedSecret() async {
    final entry = widget.entry;
    if (!entry.requiresAuth) return;

    // Si la credencial se creó por quick-add (sin cifrado), revela el secret directo
    if (entry.encryptedSecret == null ||
        entry.cipherNonce == null ||
        entry.cipherTag == null) {
      if (entry.secret != null) {
        setState(() => _revealedSecret = entry.secret);
        // Auto-ocultar después de 30 segundos
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
        // Recovery succeeded — the dialog cached the new DEK.
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
        // User entered a valid master password.
        final password = result.password!;

        // Unwrap DEK from encrypted storage key.
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
          // Pre-migration: derive key directly from password.
          key = await auth.deriveMasterKey(
            password: password,
            salt: salt,
          );
        }
        masterKeyNotifier.setMasterPassword(key);
      }
    }

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

      // Clear cached key so next reveal prompts for password again.
      masterKeyNotifier.clearMasterPassword();

      _hideTimer?.cancel();
      _hideTimer = Timer(const Duration(seconds: 30), () {
        if (!mounted) return;
        setState(() => _revealedSecret = null);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al descifrar: ${e.toString()}')),
        );
      }
    }
  }

  /// Shows the master password reveal dialog with inline verification.
  ///
  /// The dialog includes:
  /// - Password field with visibility toggle and inline error
  /// - "Show hint" toggle (if a hint exists)
  /// - "Forgot password?" link → opens [MasterPasswordRecoveryDialog]
  ///
  /// Returns the result indicating what action the user took.
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
                onSubmitted: loading ? null : (_) => verifyAndPop(ctx, setLocalState),
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
                          color: Theme.of(ctx).colorScheme.tertiary),
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
                  : () =>
                      Navigator.pop(ctx, _RevealDialogResult.cancelled()),
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

  Widget _fieldCard({
    required IconData icon,
    required String label,
    required String value,
    bool obscure = false,
    VoidCallback? onCopy,
    VoidCallback? onToggleObscure,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(
                    obscure ? '?' * (value.length.clamp(6, 20)) : (value.isNotEmpty ? value : '(vacío)'),
                    style: const TextStyle(fontSize: 15, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
            if (onCopy != null && value.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.copy, size: 18),
                tooltip: 'Copiar',
                onPressed: onCopy,
              ),
            if (onToggleObscure != null)
              IconButton(
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, size: 18),
                tooltip: obscure ? 'Mostrar' : 'Ocultar',
                onPressed: onToggleObscure,
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showPalettePicker(BuildContext context, WidgetRef ref, Entry entry, String tagName) async {
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
      await ref.read(saveTagSettingProvider).call(
        tagName,
        color: selectedHex.isEmpty ? null : selectedHex,
        isSystem: existingIsSystem,
      );
      ref.invalidate(tagSettingsListProvider);
    }
  }
}

/// Autocomplete field for tags inside the entry edit bottom sheet.
///
/// Provides real-time tag suggestions from [tagsListProvider] with a 300ms
/// debounce, minimum 1-char threshold, and max 6 visible suggestions.
class _TagsAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final WidgetRef ref;

  const _TagsAutocompleteField({
    required this.controller,
    required this.ref,
  });

  @override
  State<_TagsAutocompleteField> createState() => _TagsAutocompleteFieldState();
}

class _TagsAutocompleteFieldState extends State<_TagsAutocompleteField> {
  List<String> _suggestions = [];
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounceTimer?.cancel();
    setState(() => _suggestions = []);
    if (value.trim().isEmpty) return;

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final allTags = widget.ref.read(tagsListProvider);
      final filtered = allTags
          .where((t) => t.toLowerCase().contains(value.toLowerCase()))
          .take(6)
          .toList();
      setState(() => _suggestions = filtered);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue value) {
        return _suggestions;
      },
      fieldViewBuilder: (
        BuildContext context,
        TextEditingController autocompleteController,
        FocusNode focusNode,
        VoidCallback onFieldSubmitted,
      ) {
        return TextField(
          controller: widget.controller,
          focusNode: focusNode,
          onChanged: (String text) {
            _onChanged(text);
            // Keep the Autocomplete's own controller in sync so its
            // internal listener triggers optionsBuilder.
            autocompleteController.text = text;
            autocompleteController.selection =
                TextSelection.collapsed(offset: text.length);
          },
          decoration: const InputDecoration(
            labelText: 'Tags (opcional)',
            hintText: 'separados por coma: dev, personal',
            border: OutlineInputBorder(),
          ),
        );
      },
      onSelected: (String value) {
        _debounceTimer?.cancel();
        _suggestions = [];
        final currentText = widget.controller.text;
        final newText = currentText.isNotEmpty &&
                !currentText.endsWith(', ') &&
                !currentText.endsWith(',')
            ? '$currentText, $value, '
            : '$currentText$value, ';
        widget.controller.text = newText;
        widget.controller.selection =
            TextSelection.collapsed(offset: newText.length);
      },
    );
  }
}
