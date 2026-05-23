import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/ui/providers/entry_providers.dart';

class CredentialFormSheet extends ConsumerStatefulWidget {
  const CredentialFormSheet({super.key});

  @override
  ConsumerState<CredentialFormSheet> createState() => _CredentialFormSheetState();
}

class _CredentialFormSheetState extends ConsumerState<CredentialFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _serviceCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  bool _isSaving = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _serviceCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _urlCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final service = _serviceCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    final url = _urlCtrl.text.trim();
    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    try {
      await ref.read(createEntryProvider).call(
        title: service,
        content: username.isNotEmpty ? 'Usuario: $username' : service,
        type: EntryType.credential,
        secret: password.isNotEmpty ? password : null,
        tags: tags,
        metadata: {
          if (username.isNotEmpty) 'username': username,
          if (url.isNotEmpty) 'url': url,
        },
      );
      ref.invalidate(entryListProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.lock, size: 20),
                const SizedBox(width: 8),
                Text('Nueva credencial', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 20),

            // Servicio
            TextFormField(
              controller: _serviceCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Servicio',
                hintText: 'github, gmail, aws...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business, size: 20),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'El servicio es obligatorio' : null,
            ),
            const SizedBox(height: 12),

            // Usuario
            TextFormField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(
                labelText: 'Usuario',
                hintText: 'tu@email.com o nombre de usuario',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person, size: 20),
              ),
            ),
            const SizedBox(height: 12),

            // Contraseña
            TextFormField(
              controller: _passwordCtrl,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.key, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, size: 20),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // URL (opcional)
            TextFormField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL (opcional)',
                hintText: 'https://github.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link, size: 20),
              ),
            ),
            const SizedBox(height: 12),

            // Tags (opcional)
            TextFormField(
              controller: _tagsCtrl,
              decoration: const InputDecoration(
                labelText: 'Tags (opcional)',
                hintText: 'separados por coma: dev, personal',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label, size: 20),
              ),
            ),
            const SizedBox(height: 20),

            // Save button
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Guardando...' : 'Guardar'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
