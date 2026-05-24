import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';
import 'package:taul/infrastructure/security/master_password_store.dart';
import 'package:taul/ui/providers/entry_providers.dart';

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
  CredentialProtectionController({
    required EntryAuthService authService,
    required MasterPasswordStore passwordStore,
    MasterPasswordNotifier? masterPasswordNotifier,
  })  : _authService = authService,
        _passwordStore = passwordStore,
        _masterPasswordNotifier = masterPasswordNotifier;

  final EntryAuthService _authService;
  final MasterPasswordStore _passwordStore;
  final MasterPasswordNotifier? _masterPasswordNotifier;

  Future<ProtectionResult?> resolveProtection({
    required BuildContext context,
    required bool protectEntry,
    required bool isEditingProtectedEntry,
    required String password,
    bool passwordChanged = true,
    String? existingEncryptedSecret,
    String? existingCipherNonce,
    String? existingCipherTag,
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
    } else if (protectEntry && !passwordChanged && isEditingProtectedEntry) {
      requiresAuth = true;
      encryptedSecret = existingEncryptedSecret;
      cipherNonce = existingCipherNonce;
      cipherTag = existingCipherTag;
      finalSecret = null;
    } else if (!protectEntry && isEditingProtectedEntry) {
      clearProtection = true;
      if (password.isNotEmpty) {
        finalSecret = password;
      } else {
        final masterKey = await _getOrSetupMasterKey(context);
        if (masterKey == null) return null;
        if (existingEncryptedSecret != null &&
            existingCipherNonce != null &&
            existingCipherTag != null) {
          finalSecret = await _authService.decryptSecret(
            payload: EncryptionPayload(
              ciphertextHex: existingEncryptedSecret,
              nonceHex: existingCipherNonce,
              tagHex: existingCipherTag,
            ),
            masterKey: masterKey,
          );
        }
      }
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
    final cached = _masterPasswordNotifier?.cachedKey;
    if (cached != null) return cached;

    final current = await _passwordStore.read();
    if (current == null) {
      final password = await _askForNewMasterPassword(context);
      if (password == null) return null;
      final salt = _authService.generateSalt();
      final hash = await _authService.hashMasterPassword(password: password, salt: salt);
      await _passwordStore.save(hashHex: hash, saltHex: _authService.bytesToHex(salt));
      final key = await _authService.deriveMasterKey(password: password, salt: salt);
      _masterPasswordNotifier?.setMasterPassword(key);
      return key;
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
    final key = await _authService.deriveMasterKey(password: password, salt: salt);
    _masterPasswordNotifier?.setMasterPassword(key);
    return key;
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
