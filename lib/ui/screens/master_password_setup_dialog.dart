import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';
import 'package:taul/infrastructure/security/master_password_store.dart';
import 'package:taul/ui/providers/entry_providers.dart';

/// A reusable dialog for both first-time master password setup and password change.
///
/// [isChange] controls the mode:
/// - `false` (default): first-time setup — enter password + confirm + hint →
///   show backup codes → confirm → save
/// - `true`: change MP — enter current password → verify → enter new password
///   + confirm + hint → save (re-wraps DEK with new KEK)
class MasterPasswordSetupDialog extends ConsumerStatefulWidget {
  const MasterPasswordSetupDialog({super.key, this.isChange = false});

  final bool isChange;

  @override
  ConsumerState<MasterPasswordSetupDialog> createState() =>
      _MasterPasswordSetupDialogState();
}

class _MasterPasswordSetupDialogState
    extends ConsumerState<MasterPasswordSetupDialog> {
  // ── Controllers ──
  final _currentPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _hintCtrl = TextEditingController();

  // ── State ──
  int _step = 0;
  String? _error;
  bool _codesConfirmed = false;
  bool _saving = false;
  bool _obscurePasswords = true;

  // Crypto material generated in _onNextFromPassword, consumed in _onConfirmSetup.
  // Stored here so codes displayed to the user match the DEK-wrapped entries saved.
  Uint8List? _generatedDek;
  String? _generatedHash;
  String? _generatedSaltHex;
  EncryptionPayload? _kekWrappedEncrypted;
  ({List<String> plainCodes, List<String> codeHashes, List<BackupCodeEntry> entries})?
      _codesWithWraps;

  @override
  void dispose() {
    _currentPwCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmCtrl.dispose();
    _hintCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(widget.isChange ? 'Cambiar Contraseña Maestra' : 'Configurar Contraseña Maestra'),
        content: _buildContent(),
        actions: _buildActions(),
      ),
    );
  }

  Widget _buildContent() {
    if (_saving) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (widget.isChange) {
      return _buildChangeContent();
    }
    return _buildSetupContent();
  }

  // ── Setup mode steps ──
  //   Step 0: Enter password + confirm + optional hint
  //   Step 1: Show backup codes + confirm

  Widget _buildSetupContent() {
    if (_step == 0) {
      return _buildPasswordForm();
    }
    // Step 1: show codes
    return _buildCodesDisplay();
  }

  Widget _buildPasswordForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _newPwCtrl,
          obscureText: _obscurePasswords,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Contraseña maestra',
            helperText: 'Mínimo 8 caracteres',
            suffixIcon: IconButton(
              icon: Icon(_obscurePasswords ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscurePasswords = !_obscurePasswords),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmCtrl,
          obscureText: _obscurePasswords,
          decoration: InputDecoration(
            labelText: 'Confirmar contraseña',
            suffixIcon: IconButton(
              icon: Icon(_obscurePasswords ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscurePasswords = !_obscurePasswords),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _hintCtrl,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Pista (opcional)',
            helperText: 'Se guarda como texto plano — no uses tu contraseña ni variaciones',
            helperMaxLines: 2,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],
      ],
    );
  }

  Widget _buildCodesDisplay() {
    final codes = _codesWithWraps?.plainCodes ?? [];
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Guardá estos códigos en un lugar seguro. '
            'Son tu ÚNICA forma de recuperar el acceso si olvidás tu contraseña maestra.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
        TextButton.icon(
          icon: const Icon(Icons.copy, size: 16),
          label: const Text('Copiar todo'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: codes.join('\n')));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Códigos copiados al portapapeles')),
              );
            }
          },
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Checkbox(
              value: _codesConfirmed,
              onChanged: (v) => setState(() => _codesConfirmed = v ?? false),
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
  );
} // END _buildCodesDisplay

  // ── Change mode steps ──
  //   Step 0: Enter current password
  //   Step 1: Enter new password + confirm + optional hint

  Widget _buildChangeContent() {
    if (_step == 0) {
      return _buildCurrentPasswordForm();
    }
    return _buildNewPasswordForm();
  }

  Widget _buildCurrentPasswordForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _currentPwCtrl,
          obscureText: _obscurePasswords,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Contraseña maestra actual',
            suffixIcon: IconButton(
              icon: Icon(_obscurePasswords ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscurePasswords = !_obscurePasswords),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],
      ],
    );
  }

  Widget _buildNewPasswordForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _newPwCtrl,
          obscureText: _obscurePasswords,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Nueva contraseña maestra',
            helperText: 'Mínimo 8 caracteres',
            suffixIcon: IconButton(
              icon: Icon(_obscurePasswords ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscurePasswords = !_obscurePasswords),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmCtrl,
          obscureText: _obscurePasswords,
          decoration: InputDecoration(
            labelText: 'Confirmar nueva contraseña',
            suffixIcon: IconButton(
              icon: Icon(_obscurePasswords ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _obscurePasswords = !_obscurePasswords),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _hintCtrl,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Pista (opcional)',
            helperText: 'Se guarda como texto plano — no uses tu contraseña ni variaciones',
            helperMaxLines: 2,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],
      ],
    );
  }

  // ── Actions ──

  List<Widget> _buildActions() {
    if (_saving) {
      return [];
    }

    if (widget.isChange) {
      return _buildChangeActions();
    }
    return _buildSetupActions();
  }

  List<Widget> _buildSetupActions() {
    if (_step == 0) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _onNextFromPassword,
          child: const Text('Siguiente'),
        ),
      ];
    }
    // Step 1: codes display
    return [
      TextButton(
        onPressed: () => setState(() {
          _step = 0;
          _error = null;
        }),
        child: const Text('Volver'),
      ),
      FilledButton(
        onPressed: _codesConfirmed ? _onConfirmSetup : null,
        child: const Text('Confirmar'),
      ),
    ];
  }

  List<Widget> _buildChangeActions() {
    if (_step == 0) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _onVerifyCurrentPassword,
          child: const Text('Verificar'),
        ),
      ];
    }
    // Step 1: new password
    return [
      TextButton(
        onPressed: () => setState(() {
          _step = 0;
          _error = null;
        }),
        child: const Text('Volver'),
      ),
      FilledButton(
        onPressed: _onConfirmChange,
        child: const Text('Cambiar'),
      ),
    ];
  }

  // ── Logic ──

  Future<void> _onNextFromPassword() async {
    setState(() {
      _error = null;
      _saving = true;
    });

    final pwd = _newPwCtrl.text;
    final confirm = _confirmCtrl.text;

    if (pwd.length < 8) {
      setState(() {
        _error = 'Mínimo 8 caracteres';
        _saving = false;
      });
      return;
    }
    if (pwd != confirm) {
      setState(() {
        _error = 'Las contraseñas no coinciden';
        _saving = false;
      });
      return;
    }

    // Generate DEK, salt, hash, KEK wrap, and backup codes with DEK wraps
    // all at once so the codes shown to the user match what gets saved.
    final authService = ref.read(entryAuthServiceProvider);
    final dek = authService.generateStorageKey();
    final salt = authService.generateSalt();
    final hash = await authService.hashMasterPassword(password: pwd, salt: salt);
    final kek = await authService.deriveMasterKey(password: pwd, salt: salt);
    final wrapped = await authService.wrapStorageKey(dek: dek, kek: kek);
    final codesWithWraps = await authService.generateBackupCodesWithDekWraps(dek);

    if (!mounted) return;
    setState(() {
      _generatedDek = dek;
      _generatedHash = hash;
      _generatedSaltHex = authService.bytesToHex(salt);
      _kekWrappedEncrypted = wrapped;
      _codesWithWraps = codesWithWraps;
      _step = 1;
      _saving = false;
    });
  }

  Future<void> _onConfirmSetup() async {
    setState(() => _saving = true);

    try {
      final store = ref.read(masterPasswordStoreProvider);
      final notifier = ref.read(masterPasswordProvider.notifier);

      final hint = _hintCtrl.text.trim();
      final codesJson = jsonEncode(_codesWithWraps!.codeHashes);
      final backupCodeDataJson = jsonEncode(
        _codesWithWraps!.entries.map((e) => e.toJson()).toList(),
      );

      await store.saveFull(
        hashHex: _generatedHash!,
        saltHex: _generatedSaltHex!,
        hint: hint.isNotEmpty ? hint : null,
        backupCodeHashesJson: codesJson,
        encryptedStorageKeyHex: _kekWrappedEncrypted!.ciphertextHex,
        encryptedStorageKeyNonceHex: _kekWrappedEncrypted!.nonceHex,
        encryptedStorageKeyTagHex: _kekWrappedEncrypted!.tagHex,
        backupCodeDataJson: backupCodeDataJson,
      );

      notifier.setMasterPassword(_generatedDek!);

      if (context.mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Error al guardar: $e';
      });
    }
  }

  Future<void> _onVerifyCurrentPassword() async {
    setState(() => _error = null);

    final currentPw = _currentPwCtrl.text;
    if (currentPw.isEmpty) {
      setState(() => _error = 'Ingresá tu contraseña maestra actual');
      return;
    }

    final authService = ref.read(entryAuthServiceProvider);
    final store = ref.read(masterPasswordStoreProvider);
    final config = await store.readFull();

    if (config == null || config.encryptedStorageKeyHex == null) {
      setState(() => _error = 'No hay contraseña maestra configurada');
      return;
    }

    final salt = authService.hexToBytes(config.saltHex);
    final isValid = await authService.verifyMasterPassword(
      password: currentPw,
      salt: salt,
      expectedHashHex: config.hashHex,
    );

    if (!isValid) {
      setState(() => _error = 'La contraseña actual es incorrecta');
      return;
    }

    // Pre-fill hint from existing config
    if (config.passwordHint != null && config.passwordHint!.isNotEmpty) {
      _hintCtrl.text = config.passwordHint!;
    }

    setState(() => _step = 1);
  }

  Future<void> _onConfirmChange() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final authService = ref.read(entryAuthServiceProvider);
      final store = ref.read(masterPasswordStoreProvider);
      final notifier = ref.read(masterPasswordProvider.notifier);

      final currentPw = _currentPwCtrl.text;
      final newPw = _newPwCtrl.text;
      final confirm = _confirmCtrl.text;
      final hint = _hintCtrl.text.trim();

      // Validate new password
      if (newPw.length < 8) {
        setState(() {
          _saving = false;
          _error = 'Mínimo 8 caracteres';
        });
        return;
      }
      if (newPw != confirm) {
        setState(() {
          _saving = false;
          _error = 'Las contraseñas no coinciden';
        });
        return;
      }

      final config = await store.readFull();
      if (config == null) {
        setState(() {
          _saving = false;
          _error = 'Configuración no encontrada';
        });
        return;
      }

      // Decrypt DEK with old KEK
      final oldSalt = authService.hexToBytes(config.saltHex);
      final oldKek = await authService.deriveMasterKey(
        password: currentPw,
        salt: oldSalt,
      );
      final dek = await authService.unwrapStorageKey(
        payload: EncryptionPayload(
          ciphertextHex: config.encryptedStorageKeyHex!,
          nonceHex: config.encryptedStorageKeyNonceHex ?? '',
          tagHex: config.encryptedStorageKeyTagHex ?? '',
        ),
        kek: oldKek,
      );

      // Derive new KEK and re-wrap DEK
      final newSalt = authService.generateSalt();
      final newHash = await authService.hashMasterPassword(
        password: newPw,
        salt: newSalt,
      );
      final newKek = await authService.deriveMasterKey(
        password: newPw,
        salt: newSalt,
      );
      final newWrapped = await authService.wrapStorageKey(dek: dek, kek: newKek);

      // Preserve existing backup codes and DEK wraps
      final existingCodes = config.backupCodeHashes;
      final codesJson =
          existingCodes != null ? jsonEncode(existingCodes) : null;

      await store.saveFull(
        hashHex: newHash,
        saltHex: authService.bytesToHex(newSalt),
        hint: hint.isNotEmpty ? hint : null,
        backupCodeHashesJson: codesJson,
        backupCodeDataJson: config.backupCodeData,
        encryptedStorageKeyHex: newWrapped.ciphertextHex,
        encryptedStorageKeyNonceHex: newWrapped.nonceHex,
        encryptedStorageKeyTagHex: newWrapped.tagHex,
      );

      // Clear cached DEK — user must re-enter on next use
      notifier.clearMasterPassword();

      if (context.mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Error al cambiar la contraseña: $e';
      });
    }
  }
}
