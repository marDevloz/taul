import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';
import 'package:taul/infrastructure/security/encrypted_db_bootstrap.dart';
import 'package:taul/infrastructure/security/lockout_service.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/widgets/master_password_recovery_dialog.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Lock icon ──
                Icon(
                  Icons.lock_outline_rounded,
                  size: 72,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 16),

                // ── Title ──
                Text(
                  'Taúl',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresá tu contraseña maestra para desbloquear',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // ── Password field ──
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _onUnlock(),
                  decoration: InputDecoration(
                    labelText: 'Contraseña maestra',
                    prefixIcon: const Icon(Icons.key_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: const OutlineInputBorder(),
                    errorText: _error,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Unlock button ──
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _onUnlock,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.lock_open_rounded),
                    label: Text(_loading ? 'Verificando...' : 'Desbloquear'),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Forgot password link ──
                TextButton(
                  onPressed: _loading ? null : _onForgotPassword,
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onUnlock() async {
    final lockout = LockoutService.instance;
    final password = _passwordCtrl.text;
    if (password.isEmpty) {
      setState(() => _error = 'Ingresá tu contraseña maestra');
      return;
    }

    if (lockout.isLockedOut('master_password')) {
      final remaining = lockout.lockoutRemaining('master_password');
      setState(() => _error =
          'Demasiados intentos fallidos. Esperá ${remaining?.inSeconds ?? 30}s');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final authService = ref.read(entryAuthServiceProvider);
      final dbEncrypted = await EncryptedDbBootstrap.isEncrypted();

      String? saltHex;
      String? hashHex;
      String? wrappedDekHex;
      String? wrappedNonceHex;
      String? wrappedTagHex;

      if (dbEncrypted) {
        // DB is encrypted — read MP config from SharedPreferences.
        final bootstrap = await EncryptedDbBootstrap.read();
        if (bootstrap == null) {
          ref.read(appLockProvider.notifier).unlock();
          return;
        }
        saltHex = bootstrap.saltHex;
        hashHex = bootstrap.hashHex;
        wrappedDekHex = bootstrap.wrappedDekHex;
        wrappedNonceHex = bootstrap.wrappedNonceHex;
        wrappedTagHex = bootstrap.wrappedTagHex;
      } else {
        // DB is unencrypted — read from DB as before.
        final store = ref.read(masterPasswordStoreProvider);
        final config = await store.readFull();

        if (config == null) {
          ref.read(appLockProvider.notifier).unlock();
          return;
        }

        saltHex = config.saltHex;
        hashHex = config.hashHex;
        wrappedDekHex = config.encryptedStorageKeyHex;
        wrappedNonceHex = config.encryptedStorageKeyNonceHex;
        wrappedTagHex = config.encryptedStorageKeyTagHex;
      }

      final salt = authService.hexToBytes(saltHex);
      final isValid = await authService.verifyMasterPassword(
        password: password,
        salt: salt,
        expectedHashHex: hashHex,
      );

      if (!isValid) {
        final locked = lockout.recordFailedAttempt('master_password');
        setState(() {
          _error = locked
              ? 'Demasiados intentos fallidos. Esperá ${LockoutService.masterPasswordLockoutSeconds}s'
              : 'Contraseña incorrecta';
          _loading = false;
        });
        return;
      }

      // Success — reset attempts
      lockout.resetAttempts('master_password');

      // Derive KEK and unwrap DEK
      final kek = await authService.deriveMasterKey(
        password: password,
        salt: salt,
      );

      if (wrappedDekHex != null && wrappedDekHex.isNotEmpty) {
        final dek = await authService.unwrapStorageKey(
          payload: EncryptionPayload(
            ciphertextHex: wrappedDekHex,
            nonceHex: wrappedNonceHex ?? '',
            tagHex: wrappedTagHex ?? '',
          ),
          kek: kek,
        );
        ref.read(masterPasswordProvider.notifier).setMasterPassword(dek);
      } else {
        // Pre-migration: cache the KEK directly as the master key
        ref.read(masterPasswordProvider.notifier).setMasterPassword(kek);
      }

      if (!context.mounted) return;
      ref.read(appLockProvider.notifier).unlock();
    } catch (e) {
      setState(() {
        _error = 'Error al verificar: $e';
        _loading = false;
      });
    }
  }

  Future<void> _onForgotPassword() async {
    final result = await showDialog<RecoveryResult>(
      context: context,
      builder: (_) => const MasterPasswordRecoveryDialog(),
    );

    if (result != null && result.success && mounted) {
      ref.read(appLockProvider.notifier).unlock();
    }
  }
}
