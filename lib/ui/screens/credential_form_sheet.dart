import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/screens/credential_protection_controller.dart';

class CredentialFormSheet extends ConsumerStatefulWidget {
  final Entry? entry;

  const CredentialFormSheet({super.key, this.entry});

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
  bool _protectEntry = false;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    if (entry != null) {
      _serviceCtrl.text = entry.title;
      _usernameCtrl.text = entry.metadata['username'] ?? '';
      _passwordCtrl.text = entry.requiresAuth ? '' : (entry.secret ?? '');
      _urlCtrl.text = entry.metadata['url'] ?? '';
      _tagsCtrl.text = entry.tags.join(', ');
      _protectEntry = entry.requiresAuth;
    }
  }

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
      final passwordChanged =
          !_isEditing || !widget.entry!.requiresAuth || password.isNotEmpty;
      final effectivePassword = passwordChanged ? password : '';

      final controller = CredentialProtectionController(
        authService: ref.read(entryAuthServiceProvider),
        passwordStore: ref.read(masterPasswordStoreProvider),
        masterPasswordNotifier: ref.read(masterPasswordProvider.notifier),
      );
      final protection = await controller.resolveProtection(
        context: context,
        protectEntry: _protectEntry,
        isEditingProtectedEntry: _isEditing && widget.entry!.requiresAuth,
        password: effectivePassword,
        passwordChanged: passwordChanged,
        existingEncryptedSecret: widget.entry?.encryptedSecret,
        existingCipherNonce: widget.entry?.cipherNonce,
        existingCipherTag: widget.entry?.cipherTag,
      );

      if (protection == null) {
        setState(() => _isSaving = false);
        return;
      }

      if (_isEditing) {
        final entry = widget.entry!;
        await ref.read(updateEntryProvider).call(
          entry,
          title: service,
          secret: protection.secret,
          requiresAuth: protection.requiresAuth,
          encryptedSecret: protection.encryptedSecret,
          cipherNonce: protection.cipherNonce,
          cipherTag: protection.cipherTag,
          clearProtection: protection.clearProtection,
          tags: tags,
          metadata: {
            if (username.isNotEmpty) 'username': username,
            if (url.isNotEmpty) 'url': url,
          },
        );
        ref.invalidate(entryDetailProvider(entry.id));
      } else {
        await ref.read(createEntryProvider).call(
          title: service,
          content: username.isNotEmpty ? 'Usuario: $username' : service,
          type: EntryType.credential,
          secret: protection.secret,
          requiresAuth: protection.requiresAuth,
          encryptedSecret: protection.encryptedSecret,
          cipherNonce: protection.cipherNonce,
          cipherTag: protection.cipherTag,
          tags: tags,
          metadata: {
            if (username.isNotEmpty) 'username': username,
            if (url.isNotEmpty) 'url': url,
          },
        );
      }
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
            Row(
              children: [
                const Icon(Icons.lock, size: 20),
                const SizedBox(width: 8),
                Text(
                  _isEditing ? 'Editar credencial' : 'Nueva credencial',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 20),
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
            TextFormField(
              controller: _passwordCtrl,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                hintText: _isEditing && widget.entry!.requiresAuth ? '••••••••' : null,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.key, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, size: 20),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _protectEntry,
              onChanged: (value) => setState(() => _protectEntry = value),
              title: const Text('Proteger con master password'),
              subtitle: const Text('Cifra este secreto con AES-256-GCM'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),
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
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Guardando...' : (_isEditing ? 'Actualizar' : 'Guardar')),
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
