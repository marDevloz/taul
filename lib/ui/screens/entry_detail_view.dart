import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/screens/credential_form_sheet.dart';
import 'package:taul/ui/widgets/master_password_recovery_dialog.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(entryAsync.valueOrNull?.type.label ?? 'Entrada'),
        actions: [
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
        data: (entry) => entry.type == EntryType.credential
            ? _CredentialContent(entry: entry)
            : _NoteContent(entry: entry),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
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
    };
  }

  String _labelForType(EntryType type) {
    return switch (type) {
      EntryType.note => 'Nota',
      EntryType.idea => 'Idea',
      EntryType.glossary => 'Glosario',
      EntryType.credential => 'Credencial',
    };
  }

  void _showNoteEdit(BuildContext context, WidgetRef ref, Entry entry) {
    final titleCtrl = TextEditingController(text: entry.title);
    final contentCtrl = TextEditingController(text: entry.content);
    final tagsCtrl = TextEditingController(text: entry.tags.join(', '));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        var selectedType = entry.type;
        var isSaving = false;

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
                TextField(
                  controller: contentCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Contenido',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 5,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tagsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tags (opcional)',
                    hintText: 'separados por coma: dev, personal',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Tipo:', style: Theme.of(ctx).textTheme.bodySmall),
                    const SizedBox(width: 8),
                    PopupMenuButton<EntryType>(
                      onSelected: (t) => setLocalState(() => selectedType = t),
                      child: Chip(
                        avatar: Icon(_iconForType(selectedType), size: 16),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_labelForType(selectedType), style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade600),
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
                                final tags = tagsCtrl.text
                                    .split(',')
                                    .map((t) => t.trim())
                                    .where((t) => t.isNotEmpty)
                                    .toList();
                                await ref.read(updateEntryProvider).call(
                                  entry,
                                  title: titleCtrl.text,
                                  content: contentCtrl.text,
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

class _NoteContent extends StatelessWidget {
  final Entry entry;
  const _NoteContent({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Chip(label: Text(entry.type.label)),
          const SizedBox(height: 8),
          Text(entry.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(entry.content, style: theme.textTheme.bodyLarge),
          if (entry.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 6, children: entry.tags.map((t) => Chip(label: Text(t))).toList()),
          ],
          if (entry.topicKey != null) ...[
            const SizedBox(height: 8),
            Text('Tema: ${entry.topicKey}', style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 24),
          Text('Creado: ${_formatDate(entry.createdAt)}', style: theme.textTheme.bodySmall),
          Text('Actualizado: ${_formatDate(entry.updatedAt)}', style: theme.textTheme.bodySmall),
          Text('Versión: ${entry.version}', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                const Icon(Icons.lock, size: 40, color: Colors.amber),
                const SizedBox(height: 8),
                Text(entry.title, style: theme.textTheme.headlineSmall),
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
            Wrap(spacing: 6, children: entry.tags.map((t) => Chip(label: Text(t))).toList()),
          ],
          const SizedBox(height: 24),
          Text('Creado: ${_formatDate(entry.createdAt)}', style: theme.textTheme.bodySmall),
          Text('Actualizado: ${_formatDate(entry.updatedAt)}', style: theme.textTheme.bodySmall),
          Text('Versión: ${entry.version}', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Future<void> _revealProtectedSecret() async {
    final entry = widget.entry;
    if (!entry.requiresAuth ||
        entry.encryptedSecret == null ||
        entry.cipherNonce == null ||
        entry.cipherTag == null) {
      return;
    }

    final auth = ref.read(entryAuthServiceProvider);
    final masterKeyNotifier = ref.read(masterPasswordProvider.notifier);
    Uint8List? key = masterKeyNotifier.cachedKey;

    if (key == null) {
      final result = await _showMasterPasswordDialog(entry: entry);
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
        // User entered a master password.
        final password = result.password!;
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
        final isValid = await auth.verifyMasterPassword(
          password: password,
          salt: salt,
          expectedHashHex: config.hashHex,
        );

        if (!isValid) {
          // Wrong password — show recovery option.
          final recoveryChosen = await _showRecoveryOption();
          if (!recoveryChosen || !mounted) return;

          final recovered = await _openRecoveryDialog();
          if (!recovered || !mounted) return;

          // After recovery, key should be cached.
          key = masterKeyNotifier.cachedKey;
          if (key == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Recuperación completada pero no se pudo cargar la clave.',
                  ),
                ),
              );
            }
            return;
          }
        } else {
          // Valid password: unwrap DEK from encrypted storage key.
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

  /// Shows the master password reveal dialog with hint and recovery link.
  ///
  /// The dialog includes:
  /// - Password field
  /// - "Show hint" toggle (if a hint exists)
  /// - "Forgot password?" link → opens [MasterPasswordRecoveryDialog]
  ///
  /// Returns the result indicating what action the user took.
  Future<_RevealDialogResult?> _showMasterPasswordDialog({
    required Entry entry,
  }) async {
    final hint = await ref.read(masterPasswordHintProvider.future);
    final ctrl = TextEditingController();
    var showHint = false;

    final result = await showDialog<_RevealDialogResult>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Contraseña Maestra'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Ingresá tu contraseña maestra',
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
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade200),
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
                onPressed: () async {
                  // Open recovery dialog on top of this one.
                  final recoveryResult = await Navigator.push<RecoveryResult>(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => const MasterPasswordRecoveryDialog(),
                      fullscreenDialog: true,
                    ),
                  );
                  // If recovery succeeded, close THIS dialog too.
                  if (recoveryResult != null && recoveryResult.success) {
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
              onPressed: () =>
                  Navigator.pop(ctx, _RevealDialogResult.cancelled()),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final text = ctrl.text;
                if (text.trim().isEmpty) return;
                Navigator.pop(
                  ctx,
                  _RevealDialogResult.password(text),
                );
              },
              child: const Text('Aceptar'),
            ),
          ],
        ),
      ),
    );

    ctrl.dispose();
    return result;
  }

  /// Shows an option to try recovery after a wrong password.
  /// Returns true if the user wants to start recovery.
  Future<bool> _showRecoveryOption() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contraseña Incorrecta'),
        content: const Text(
          'La contraseña maestra que ingresaste es incorrecta. '
          'Podés intentar de nuevo o usar un código de respaldo para recuperar el acceso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Intentar de nuevo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Usar Código de Respaldo'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Opens the [MasterPasswordRecoveryDialog] and returns true if recovery
  /// was completed successfully.
  Future<bool> _openRecoveryDialog() async {
    final result = await Navigator.push<RecoveryResult>(
      context,
      MaterialPageRoute(
        builder: (_) => const MasterPasswordRecoveryDialog(),
        fullscreenDialog: true,
      ),
    );
    return result?.success ?? false;
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
            Icon(icon, size: 20, color: Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
}

