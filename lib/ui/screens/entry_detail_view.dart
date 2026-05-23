import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/ui/providers/entry_providers.dart';

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
      _showCredentialEdit(context, ref, entry);
    } else {
      _showNoteEdit(context, ref, entry);
    }
  }

  void _showNoteEdit(BuildContext context, WidgetRef ref, Entry entry) {
    final titleCtrl = TextEditingController(text: entry.title);
    final contentCtrl = TextEditingController(text: entry.content);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar entrada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Título')),
            const SizedBox(height: 12),
            TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: 'Contenido'), maxLines: 5),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(updateEntryProvider).call(
                entry,
                title: titleCtrl.text,
                content: contentCtrl.text,
              );
              ref.invalidate(entryDetailProvider(entryId));
              ref.invalidate(entryListProvider);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showCredentialEdit(BuildContext context, WidgetRef ref, Entry entry) {
    final serviceCtrl = TextEditingController(text: entry.title);
    final usernameCtrl = TextEditingController(text: entry.metadata['username'] ?? '');
    final passwordCtrl = TextEditingController(text: entry.secret ?? '');
    final urlCtrl = TextEditingController(text: entry.metadata['url'] ?? '');
    final tagsCtrl = TextEditingController(text: entry.tags.join(', '));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar credencial'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: serviceCtrl, decoration: const InputDecoration(labelText: 'Servicio')),
              const SizedBox(height: 12),
              TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'Usuario')),
              const SizedBox(height: 12),
              TextField(controller: passwordCtrl, decoration: const InputDecoration(labelText: 'Contraseña')),
              const SizedBox(height: 12),
              TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'URL')),
              const SizedBox(height: 12),
              TextField(controller: tagsCtrl, decoration: const InputDecoration(labelText: 'Tags')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final tags = tagsCtrl.text
                  .split(',')
                  .map((t) => t.trim())
                  .where((t) => t.isNotEmpty)
                  .toList();
              await ref.read(updateEntryProvider).call(
                entry,
                title: serviceCtrl.text,
                secret: passwordCtrl.text.isNotEmpty ? passwordCtrl.text : null,
                tags: tags,
                metadata: {
                  if (usernameCtrl.text.trim().isNotEmpty) 'username': usernameCtrl.text.trim(),
                  if (urlCtrl.text.trim().isNotEmpty) 'url': urlCtrl.text.trim(),
                },
              );
              ref.invalidate(entryDetailProvider(entryId));
              ref.invalidate(entryListProvider);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
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

// ─── Note / Idea / Glossary content ───────────────────────────────

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

// ─── Credential content ───────────────────────────────────────────

class _CredentialContent extends StatefulWidget {
  final Entry entry;
  const _CredentialContent({required this.entry});

  @override
  State<_CredentialContent> createState() => _CredentialContentState();
}

class _CredentialContentState extends State<_CredentialContent> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;
    final username = entry.metadata['username'] ?? '';
    final url = entry.metadata['url'] ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service name
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

          // Username
          if (username.isNotEmpty) ...[
            _fieldCard(
              icon: Icons.person,
              label: 'Usuario',
              value: username,
              onCopy: () => Clipboard.setData(ClipboardData(text: username)),
            ),
            const SizedBox(height: 12),
          ],

          // Password
          _fieldCard(
            icon: Icons.key,
            label: 'Contraseña',
            value: entry.secret ?? '',
            obscure: !_showPassword,
            onCopy: () {
              if (entry.secret != null) {
                Clipboard.setData(ClipboardData(text: entry.secret!));
              }
            },
            onToggleObscure: () => setState(() => _showPassword = !_showPassword),
          ),
          const SizedBox(height: 12),

          // URL
          if (url.isNotEmpty) ...[
            _fieldCard(
              icon: Icons.link,
              label: 'URL',
              value: url,
              onCopy: () => Clipboard.setData(ClipboardData(text: url)),
            ),
            const SizedBox(height: 12),
          ],

          // Tags
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
                    obscure ? '●' * (value.length.clamp(6, 20)) : (value.isNotEmpty ? value : '(vacío)'),
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
