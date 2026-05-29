import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';
import 'package:taul/infrastructure/security/master_password_store.dart';
import 'package:taul/ui/providers/entry_providers.dart';

/// Thrown when the user cancels the master password prompt dialog.
class UserCancelledException implements Exception {
  const UserCancelledException();
}

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
  Uint8List? _cachedDek;

  /// Checks whether the master password is fully configured
  /// (i.e., an encrypted storage key exists in the DB).
  Future<bool> isConfigured() async {
    final config = await _passwordStore.readFull();
    return config != null &&
        config.encryptedStorageKeyHex != null &&
        config.encryptedStorageKeyHex!.isNotEmpty;
  }

  /// Returns the stored password hint, or null if not set.
  Future<String?> getHint() => _passwordStore.readHint();

  /// Returns how many backup codes remain (0 if none or not configured).
  Future<int> getRemainingCodeCount() async {
    final hashes = await _passwordStore.readBackupCodeHashes();
    return hashes?.length ?? 0;
  }

  /// Ensures MP is configured: if not, shows the full setup dialog flow
  /// with password confirmation, optional hint, and backup codes.
  ///
  /// Returns true if MP is already configured or setup completed successfully.
  /// Returns false if the user cancelled.
  Future<bool> ensureConfigured(BuildContext context) async {
    if (await isConfigured()) return true;
    if (!context.mounted) return false;
    final key = await _getOrSetupMasterKey(context);
    return key != null;
  }

  /// Ensures MP protection is available for encryption.
  /// If MP is configured and DEK is cached, returns true silently.
  /// If MP is configured but DEK expired, prompts for password.
  /// If MP is not configured, triggers full setup.
  ///
  /// Returns true if protection is ready, false if user cancelled.
  Future<bool> ensureProtectionConfigured(BuildContext context) async {
    if (!context.mounted) return false;
    final key = await _getOrSetupMasterKey(context);
    return key != null;
  }

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

    final config = await _passwordStore.readFull();

    // ─── Case 1: MP is configured with KEK/DEK wrapping ─────────────────
    if (config != null &&
        config.encryptedStorageKeyHex != null &&
        config.encryptedStorageKeyHex!.isNotEmpty) {
      if (!context.mounted) return null;

      final salt = _authService.hexToBytes(config.saltHex);
      final password = await _askForPassword(context, verify: (pwd) async {
        return _authService.verifyMasterPassword(
          password: pwd,
          salt: salt,
          expectedHashHex: config.hashHex,
        );
      });
      if (password == null) return null;

      // Derive KEK and unwrap DEK
      final kek = await _authService.deriveMasterKey(password: password, salt: salt);
      final dek = await _authService.unwrapStorageKey(
        payload: EncryptionPayload(
          ciphertextHex: config.encryptedStorageKeyHex!,
          nonceHex: config.encryptedStorageKeyNonceHex ?? '',
          tagHex: config.encryptedStorageKeyTagHex ?? '',
        ),
        kek: kek,
      );
      _masterPasswordNotifier?.setMasterPassword(dek);
      return dek;
    }

    // ─── Case 2: Config exists but no KEK/DEK (pre-migration) ──────────
    if (config != null) {
      if (!context.mounted) return null;

      final salt = _authService.hexToBytes(config.saltHex);
      final password = await _askForPassword(context, verify: (pwd) async {
        return _authService.verifyMasterPassword(
          password: pwd,
          salt: salt,
          expectedHashHex: config.hashHex,
        );
      });
      if (password == null) return null;
      final key = await _authService.deriveMasterKey(password: password, salt: salt);
      _masterPasswordNotifier?.setMasterPassword(key);
      return key;
    }

    // ─── Case 3: No config → full setup dialog ─────────────────────────
    if (!context.mounted) return null;
    final setupResult = await _showFullSetupDialog(context);
    if (setupResult == null) return null;

    final setupPassword = setupResult.password;
    final setupHint = setupResult.hint;
    final dek = _authService.generateStorageKey();
    final salt = _authService.generateSalt();
    final hash = await _authService.hashMasterPassword(
      password: setupPassword,
      salt: salt,
    );
    final kek = await _authService.deriveMasterKey(
      password: setupPassword,
      salt: salt,
    );
    final wrapped = await _authService.wrapStorageKey(dek: dek, kek: kek);

    // Generate backup codes with DEK wraps
    final codesWithWraps = await _authService.generateBackupCodesWithDekWraps(dek);
    final backupCodeDataJson = jsonEncode(
      codesWithWraps.entries.map((e) => e.toJson()).toList(),
    );

    // Show generated codes to user
    if (context.mounted) {
      final codesSaved = await _showBackupCodesDialog(
        context,
        codesWithWraps.plainCodes,
      );
      if (!codesSaved) return null;
    }

    await _passwordStore.saveFull(
      hashHex: hash,
      saltHex: _authService.bytesToHex(salt),
      hint: setupHint,
      backupCodeHashesJson: jsonEncode(codesWithWraps.codeHashes),
      encryptedStorageKeyHex: wrapped.ciphertextHex,
      encryptedStorageKeyNonceHex: wrapped.nonceHex,
      encryptedStorageKeyTagHex: wrapped.tagHex,
      backupCodeDataJson: backupCodeDataJson,
    );

    _masterPasswordNotifier?.setMasterPassword(dek);
    return dek;
  }

  /// Prompts the user for their master password, verifies it, unwraps the DEK
  /// from the stored encrypted storage key, and returns the DEK.
  ///
  /// The DEK is cached for subsequent calls so the user is only prompted once
  /// per session (or until [clearCachedDek] is called).
  ///
  /// Throws [UserCancelledException] if the user cancels the password dialog.
  /// Throws [Exception] if the password is wrong or the MP is not configured.
  Future<Uint8List> requireMasterKey(BuildContext context) async {
    if (_cachedDek != null) return _cachedDek!;

    final cached = _masterPasswordNotifier?.cachedKey;
    if (cached != null) {
      _cachedDek = cached;
      return cached;
    }

    final config = await _passwordStore.readFull();
    if (config == null ||
        config.encryptedStorageKeyHex == null ||
        config.encryptedStorageKeyHex!.isEmpty) {
      throw StateError('Master password not configured');
    }

    final salt = _authService.hexToBytes(config.saltHex);
    final password = await _askForPassword(context, verify: (pwd) async {
      return _authService.verifyMasterPassword(
        password: pwd,
        salt: salt,
        expectedHashHex: config.hashHex,
      );
    });
    if (password == null) throw const UserCancelledException();

    final kek = await _authService.deriveMasterKey(
      password: password,
      salt: salt,
    );
    final dek = await _authService.unwrapStorageKey(
      payload: EncryptionPayload(
        ciphertextHex: config.encryptedStorageKeyHex!,
        nonceHex: config.encryptedStorageKeyNonceHex ?? '',
        tagHex: config.encryptedStorageKeyTagHex ?? '',
      ),
      kek: kek,
    );

    _cachedDek = dek;
    return dek;
  }

  /// Clears the cached DEK. The next call to [requireMasterKey] will prompt
  /// the user for their master password again.
  void clearCachedDek() {
    _cachedDek = null;
  }

  /// Shows a dialog that prompts for the master password.
  ///
  /// The [verify] callback is called with the entered password.
  /// If it returns `false`, the dialog stays open and shows an inline error
  /// so the user can retry. If it returns `true`, the dialog closes with the
  /// verified password.
  ///
  /// Returns `null` if the user cancels.
  Future<String?> _askForPassword(
    BuildContext context, {
    required Future<bool> Function(String password) verify,
  }) async {
    final ctrl = TextEditingController();
    String? error;
    var obscurePassword = true;
    var loading = false;

    final value = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Master password'),
          content: TextField(
            controller: ctrl,
            obscureText: obscurePassword,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: loading ? null : (_) async {
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
                  Navigator.pop(ctx, password);
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
            },
            decoration: InputDecoration(
              labelText: 'Ingresá tu master password',
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
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: loading ? null : () async {
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
                    Navigator.pop(ctx, password);
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
              },
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
    return value;
  }

  /// Full setup dialog: password + confirm + optional hint.
  /// Returns `(password, hint)` or null if cancelled.
  Future<({String password, String? hint})?> _showFullSetupDialog(
    BuildContext context,
  ) async {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final hintCtrl = TextEditingController();
    String? error;
    final result = await showDialog<({String password, String? hint})>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Configurar master password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 12),
              TextField(
                controller: hintCtrl,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Pista (opcional)',
                  hintText: 'Ej: nombre de mi primera mascota',
                  helperText: 'Tu hint se guarda en texto plano',
                  helperMaxLines: 2,
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
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
                final hint = hintCtrl.text.trim();
                Navigator.pop(
                  ctx,
                  (password: pwd, hint: hint.isNotEmpty ? hint : null),
                );
              },
              child: const Text('Siguiente'),
            ),
          ],
        ),
      ),
    );
    return result;
  }

  /// Shows the generated backup codes and requires user confirmation.
  /// Returns true if the user confirmed saving them, false if cancelled.
  Future<bool> _showBackupCodesDialog(
    BuildContext context,
    List<String> codes,
  ) async {
    var confirmed = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Códigos de recuperación'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Guardá estos códigos en un lugar seguro. '
                'Si perdés tu master password, son tu ÚNICA forma de recuperar el acceso.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < codes.length; i++) ...[
                      if (i > 0 && i % 5 == 0) const SizedBox(height: 4),
                      Text(
                        '${(i + 1).toString().padLeft(2, '0')}. ${codes[i]}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copiar todos'),
                    onPressed: () {
                      final allCodes = codes.join('\n');
                      Clipboard.setData(ClipboardData(text: allCodes));
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Códigos copiados al portapapeles'),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.save_alt, size: 16),
                    label: const Text('Guardar como texto'),
                    onPressed: () {
                      final allCodes = codes.join('\n');
                      Clipboard.setData(ClipboardData(text: allCodes));
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Códigos copiados — pegálos en un archivo de texto seguro',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: confirmed,
                    onChanged: (v) =>
                        setLocalState(() => confirmed = v ?? false),
                  ),
                  const Expanded(
                    child: Text(
                      'Guardé mis códigos en un lugar seguro',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: confirmed ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }
}
