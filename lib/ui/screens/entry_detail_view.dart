import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';
import 'package:taul/infrastructure/security/master_password_store.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/screens/credential_form_sheet.dart';

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
              label: Text(_revealedSecret == null ? 'Reveal Secret' : 'Reveal Again'),
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

    final password = await _askForPassword();
    if (password == null || !mounted) return;

    final auth = EntryAuthService();
    final store = MasterPasswordStore(ref.read(databaseProvider));
    final config = await store.read();
    if (config == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Master password no configurada')),
      );
      return;
    }

    final salt = auth.hexToBytes(config.saltHex);
    final isValid = await auth.verifyMasterPassword(
      password: password,
      salt: salt,
      expectedHashHex: config.hashHex,
    );
    if (!isValid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Master password inválida')),
        );
      }
      return;
    }

    final key = await auth.deriveMasterKey(password: password, salt: salt);
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

    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 30), () {
      if (!mounted) return;
      setState(() => _revealedSecret = null);
    });
  }

  Future<String?> _askForPassword() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Master password'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Ingresá tu master password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || result.trim().isEmpty) return null;
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

