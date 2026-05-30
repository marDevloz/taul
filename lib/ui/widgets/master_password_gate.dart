import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';
import 'package:taul/ui/providers/entry_providers.dart';

/// Shows the master password dialog (same pattern as CredentialProtectionController)
/// and retries until the user enters the correct password or cancels.
/// Returns true if verified, false if cancelled.
Future<bool> showMasterPasswordGate({
  required BuildContext context,
  required WidgetRef ref,
}) async {
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
  final ctrl = TextEditingController();
  String? error;
  var obscurePassword = true;
  var loading = false;

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
          onSubmitted: loading
              ? null
              : (_) async {
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
            onPressed: loading
                ? null
                : () async {
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
