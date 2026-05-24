import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';
import 'package:taul/infrastructure/security/master_password_store.dart';

class ProtectionResult {
  const ProtectionResult({
    required this.secret,
    required this.requiresAuth,
    required this.clearProtection,
    this.encryptedSecret,
    this.cipherNonce,
    this.cipherTag,
  });

  final String? secret;
  final bool requiresAuth;
  final bool clearProtection;
  final String? encryptedSecret;
  final String? cipherNonce;
  final String? cipherTag;
}

class CredentialProtectionController {
  const CredentialProtectionController({
    required EntryAuthService authService,
    required MasterPasswordStore passwordStore,
  })  : _authService = authService,
        _passwordStore = passwordStore;

  final EntryAuthService _authService;
  final MasterPasswordStore _passwordStore;

  Future<ProtectionResult?> resolveProtection({
    required BuildContext context,
    required bool protectEntry,
    required bool isEditingProtectedEntry,
    required String password,
  }) async {
    var finalSecret = password.isNotEmpty ? password : null;
    var clearProtection = false;
    var requiresAuth = false;
    String? encryptedSecret;
    String? cipherNonce;
    String? cipherTag;

    if (protectEntry && password.isNotEmpty) {
      final masterKey = await _getOrSetupMasterKey(context);
      if (masterKey == null) return null;
      final payload = await _authService.encryptSecret(
        plaintext: password,
        masterKey: masterKey,
      );
      requiresAuth = true;
      finalSecret = null;
      encryptedSecret = payload.ciphertextHex;
      cipherNonce = payload.nonceHex;
      cipherTag = payload.tagHex;
    } else if (!protectEntry && isEditingProtectedEntry) {
      clearProtection = true;
    }

    return ProtectionResult(
      secret: finalSecret,
      requiresAuth: requiresAuth,
      clearProtection: clearProtection,
      encryptedSecret: encryptedSecret,
      cipherNonce: cipherNonce,
      cipherTag: cipherTag,
    );
  }

  Future<Uint8List?> _getOrSetupMasterKey(BuildContext context) async {
    final current = await _passwordStore.read();
    if (current == null) {
      final password = await _askForNewMasterPassword(context);
      if (password == null) return null;
      final salt = _authService.generateSalt();
      final hash = await _authService.hashMasterPassword(password: password, salt: salt);
      await _passwordStore.save(hashHex: hash, saltHex: _authService.bytesToHex(salt));
      return _authService.deriveMasterKey(password: password, salt: salt);
    }

    final password = await _askForPassword(context);
    if (password == null) return null;
    final salt = _authService.hexToBytes(current.saltHex);
    final isValid = await _authService.verifyMasterPassword(
      password: password,
      salt: salt,
      expectedHashHex: current.hashHex,
    );
    if (!isValid && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Master password inválida')),
      );
      return null;
    }
    return _authService.deriveMasterKey(password: password, salt: salt);
  }

  Future<String?> _askForPassword(BuildContext context) async {
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
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
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  Future<String?> _askForNewMasterPassword(BuildContext context) async {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Configurar master password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Master password'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirmar password'),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final pwd = passwordCtrl.text;
                final confirm = confirmCtrl.text;
                if (pwd.length < 8) {
                  setLocalState(() => error = 'Mínimo 8 caracteres');
                  return;
                }
                if (pwd != confirm) {
                  setLocalState(() => error = 'Las contraseñas no coinciden');
                  return;
                }
                Navigator.pop(ctx, pwd);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    passwordCtrl.dispose();
    confirmCtrl.dispose();
    return result;
  }
}
