import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';
import 'package:taul/infrastructure/security/lockout_service.dart';
import 'package:taul/ui/providers/entry_providers.dart';

/// Shows the master password dialog (same pattern as CredentialProtectionController)
/// and retries until the user enters the correct password or cancels.
/// Returns true if verified, false if cancelled.
Future<bool> showMasterPasswordGate({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final lockout = LockoutService.instance;

  // Check lockout before even showing the dialog
  if (lockout.isLockedOut('master_password')) {
    final remaining = lockout.lockoutRemaining('master_password');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Demasiados intentos fallidos. Esperá ${remaining?.inSeconds ?? 30}s',
          ),
        ),
      );
    }
    return false;
  }

  final store = ref.read(masterPasswordStoreProvider);
  final config = await store.readFull();

  if (config == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contraseña maestra no configurada. Configurala desde Ajustes.'),
        ),
      );
    }
    return false;
  }

  final auth = EntryAuthService();
  final salt = auth.hexToBytes(config.saltHex);

  // Retry loop — same as _askForPassword in CredentialProtectionController
  while (true) {
    if (!context.mounted) return false;

    final password = await _askForMasterPassword(
      context,
      verify: (pwd) => auth.verifyMasterPassword(
        password: pwd,
        salt: salt,
        expectedHashHex: config.hashHex,
      ),
    );

    if (password != null) return true;
    // null = cancelled
    return false;
  }
}

/// Master password prompt — mirrors _askForPassword from CredentialProtectionController.
/// Returns the verified password, or null if cancelled.
Future<String?> _askForMasterPassword(
  BuildContext context, {
  required Future<bool> Function(String password) verify,
}) async {
  final lockout = LockoutService.instance;
  final ctrl = TextEditingController();
  String? error;
  var obscurePassword = true;
  var loading = false;

  Future<void> onVerify(
    StateSetter setLocalState,
    String password,
    BuildContext dialogContext,
  ) async {
    if (password.isEmpty) {
      setLocalState(() => error = 'Ingresá tu contraseña');
      return;
    }
    if (lockout.isLockedOut('master_password')) {
      final remaining = lockout.lockoutRemaining('master_password');
      setLocalState(() =>
          error = 'Demasiados intentos. Esperá ${remaining?.inSeconds ?? 30}s');
      return;
    }
    setLocalState(() {
      loading = true;
      error = null;
    });
    try {
      final isValid = await verify(password);
      if (isValid) {
        lockout.resetAttempts('master_password');
        Navigator.pop(dialogContext, password);
      } else {
        final locked = lockout.recordFailedAttempt('master_password');
        setLocalState(() {
          loading = false;
          error = locked
              ? 'Demasiados intentos fallidos. Esperá ${LockoutService.masterPasswordLockoutSeconds}s'
              : 'Contraseña incorrecta';
        });
      }
    } catch (_) {
      setLocalState(() {
        loading = false;
        error = 'Error al verificar';
      });
    }
  }

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocalState) => AlertDialog(
        title: const Text('Contraseña maestra'),
        content: TextField(
          controller: ctrl,
          obscureText: obscurePassword,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: loading ? null : (_) => onVerify(setLocalState, ctrl.text, ctx),
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
            onPressed: loading ? null : () => onVerify(setLocalState, ctrl.text, ctx),
            child: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Desbloquear'),
          ),
        ],
      ),
    ),
  );
}
