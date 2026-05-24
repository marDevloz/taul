import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/ui/providers/entry_providers.dart';

/// Result of the recovery flow.
///
/// [success] indicates whether a new master password was set.
/// When [success] is true, the new DEK is cached in [MasterPasswordNotifier]
/// and can be accessed via `ref.read(masterPasswordProvider.notifier).cachedKey`.
class RecoveryResult {
  const RecoveryResult({required this.success});

  final bool success;
}

/// Recovery dialog: enter backup code → verify → set new master password.
///
/// ## Flow
/// 1. User enters a backup code (XXXX-XXXX format)
/// 2. Code is verified against stored Argon2id hashes
/// 3. On match: code is consumed atomically from the DB
/// 4. User sets a new master password + optional hint
/// 5. A new DEK is generated (existing entries encrypted with the old DEK
///    become unreachable — see design deviation notes)
/// 6. New DEK cached in [MasterPasswordNotifier]
/// 7. Dialog pops with [RecoveryResult(success: true)]
///
/// On failure (invalid code, DB error, cancel) returns
/// [RecoveryResult(success: false)].
///
/// ## Rate limiting
/// 3 failed code attempts trigger a 60-second lockout (in-memory, per dialog
/// instance). Resets if the dialog is closed and re-opened.
///
/// ## Design deviation: DEK preservation
/// The current design cannot preserve the existing DEK during recovery because
/// the DEK is stored encrypted with a KEK derived from the OLD master password.
/// Without the old password, the DEK cannot be unwrapped. Recovery generates a
/// NEW DEK, which means entries encrypted with the old DEK become unreachable.
/// A future improvement could encrypt the DEK with each backup code during
/// setup, enabling recovery without DEK loss.
class MasterPasswordRecoveryDialog extends ConsumerStatefulWidget {
  const MasterPasswordRecoveryDialog({super.key});

  @override
  ConsumerState<MasterPasswordRecoveryDialog> createState() =>
      _MasterPasswordRecoveryDialogState();
}

class _MasterPasswordRecoveryDialogState
    extends ConsumerState<MasterPasswordRecoveryDialog> {
  // ── Step 0: Code entry ──
  final _codeCtrl = TextEditingController();
  int _failedAttempts = 0;
  bool _lockoutActive = false;
  Timer? _lockoutTimer;

  // ── Step 1: New MP form ──
  final _newPwCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _hintCtrl = TextEditingController();

  // ── General state ──
  int _step = 0;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadRemainingCodes();
  }

  Future<void> _loadRemainingCodes() async {
    final store = ref.read(masterPasswordStoreProvider);
    final hashes = await store.readBackupCodeHashes();
    if (!mounted) return;
    setState(() {
      _cachedRemainingCodes = (hashes == null) ? -1 : hashes.length;
    });
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _newPwCtrl.dispose();
    _confirmCtrl.dispose();
    _hintCtrl.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(
          _step == 0 ? 'Recover Master Password' : 'Set New Master Password',
        ),
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

    if (_step == 0) return _buildCodeEntry();
    return _buildNewPasswordForm();
  }

  Widget _buildCodeEntry() {
    final remaining = _remainingCodes;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter one of your backup codes to reset your master password.',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          remaining >= 0
              ? '$remaining backup code${remaining == 1 ? '' : 's'} remaining.'
              : 'No backup codes stored.',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _codeCtrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Backup code',
            hintText: 'e.g. ABCD-1234',
            prefixIcon: Icon(Icons.vpn_key_outlined),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],
        if (_lockoutActive) ...[
          const SizedBox(height: 8),
          const Text(
            'Too many failed attempts. Please wait 60 seconds before trying '
            'again.',
            style: TextStyle(color: Colors.orange, fontSize: 13),
          ),
        ],
      ],
    );
  }

  Widget _buildNewPasswordForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Code verified. Create your new master password.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _newPwCtrl,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New master password',
            helperText: 'Minimum 8 characters',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _confirmCtrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Confirm new password'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _hintCtrl,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Hint (optional)',
            helperText: 'Your hint is stored as plain text',
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
    if (_saving) return [];

    if (_step == 0) {
      return [
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            const RecoveryResult(success: false),
          ),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _lockoutActive ? null : _onVerifyCode,
          child: const Text('Verify'),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: () => Navigator.pop(
          context,
          const RecoveryResult(success: false),
        ),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _onSetNewPassword,
        child: const Text('Set Password'),
      ),
    ];
  }

  // ── Helpers ──

  /// Returns the number of remaining backup codes, or -1 if unknown.
  int get _remainingCodes {
    // We cache this from the last _onVerifyCode call
    return _cachedRemainingCodes;
  }

  int _cachedRemainingCodes = -1;

  // ── Step 0 logic: verify backup code ──

  Future<void> _onVerifyCode() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Enter a backup code');
      return;
    }

    setState(() => _error = null);

    final store = ref.read(masterPasswordStoreProvider);
    final hashes = await store.readBackupCodeHashes();

    if (hashes == null || hashes.isEmpty) {
      setState(() {
        _cachedRemainingCodes = 0;
        _error = 'No backup codes remaining. Recovery is not possible.';
      });
      return;
    }

    _cachedRemainingCodes = hashes.length;

    // Verify code against stored hashes
    final service = ref.read(recoveryServiceProvider);
    final matchIndex = await service.verifyBackupCode(code, hashes);

    if (matchIndex < 0) {
      setState(() {
        _failedAttempts++;
        if (_failedAttempts >= 3) {
          _lockoutActive = true;
          _lockoutTimer = Timer(const Duration(seconds: 60), () {
            if (mounted) setState(() => _lockoutActive = false);
          });
          _error = 'Too many failed attempts. '
              'Please wait 60 seconds before trying again.';
        } else {
          final remainingTries = hashes.length;
          final codeWord = remainingTries == 1 ? 'code' : 'codes';
          _error = 'Invalid code. '
              '$remainingTries backup $codeWord remaining.';
        }
      });
      return;
    }

    // Code matched → consume it atomically within a DB transaction.
    // If the DB write fails, the code hash is NOT removed — safe to retry.
    final consumed = await store.consumeBackupCodeAtIndex(matchIndex);
    if (!consumed) {
      setState(() {
        _error = 'An error occurred while processing the code. '
            'Please try again — the code has not been consumed.';
      });
      return;
    }

    // Pre-fill hint from existing config for convenience
    final config = await store.readFull();
    if (config?.passwordHint != null && config!.passwordHint!.isNotEmpty) {
      _hintCtrl.text = config.passwordHint!;
    }

    setState(() {
      _step = 1;
      _error = null;
    });
  }

  // ── Step 1 logic: set new master password ──

  Future<void> _onSetNewPassword() async {
    setState(() => _error = null);

    final newPw = _newPwCtrl.text;
    final confirm = _confirmCtrl.text;
    final hint = _hintCtrl.text.trim();

    if (newPw.length < 8) {
      setState(() => _error = 'Minimum 8 characters');
      return;
    }
    if (newPw != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() => _saving = true);

    try {
      final authService = ref.read(entryAuthServiceProvider);
      final store = ref.read(masterPasswordStoreProvider);
      final notifier = ref.read(masterPasswordProvider.notifier);

      // Generate a new DEK, salt, and KEK.
      // NOTE: The old DEK (stored encrypted with the old KEK) cannot be
      // recovered without knowing the old master password. A new DEK is
      // generated, which means existing entries encrypted with the old DEK
      // become unreachable. See class-level doc for details.
      final dek = authService.generateStorageKey();
      final salt = authService.generateSalt();
      final hash = await authService.hashMasterPassword(
        password: newPw,
        salt: salt,
      );
      final kek = await authService.deriveMasterKey(
        password: newPw,
        salt: salt,
      );
      final wrapped = await authService.wrapStorageKey(dek: dek, kek: kek);

      // Generate new backup codes to replace the consumed one
      final codesResult = await authService.generateBackupCodes();
      final codesJson = jsonEncode(codesResult.codeHashes);

      await store.saveFull(
        hashHex: hash,
        saltHex: authService.bytesToHex(salt),
        hint: hint.isNotEmpty ? hint : null,
        backupCodeHashesJson: codesJson,
        encryptedStorageKeyHex: wrapped.ciphertextHex,
        encryptedStorageKeyNonceHex: wrapped.nonceHex,
        encryptedStorageKeyTagHex: wrapped.tagHex,
      );

      notifier.setMasterPassword(dek);

      if (context.mounted) {
        Navigator.pop(context, const RecoveryResult(success: true));
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Error saving: $e';
      });
    }
  }
}
