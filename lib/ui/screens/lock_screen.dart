import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:taul/core/constants.dart';
import 'package:taul/infrastructure/security/db_migration_service.dart';
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

      Uint8List masterKey;
      String? migrationMessage;
      bool migrationFailed = false;

      if (dbEncrypted) {
        // DB is encrypted — unwrap DEK from bootstrap
        final dek = await authService.unwrapStorageKey(
          payload: EncryptionPayload(
            ciphertextHex: wrappedDekHex!,
            nonceHex: wrappedNonceHex ?? '',
            tagHex: wrappedTagHex ?? '',
          ),
          kek: kek,
        );
        masterKey = dek;
      } else {
        // DB is unencrypted — check if migration is needed
        final store = ref.read(masterPasswordStoreProvider);
        final config = await store.readFull();

        final hasDek = config != null &&
            config.encryptedStorageKeyHex != null &&
            config.encryptedStorageKeyHex!.isNotEmpty;

        if (config != null && !hasDek) {
          // Old user: has master password but no DEK → migrate
          setState(() => _loading = true);
          final dbFolder = await getApplicationDocumentsDirectory();
          final dbFile = File('${dbFolder.path}/${AppConstants.databaseName}');
          final migrationService = DbMigrationService();

          final dek = await migrationService.migrateExistingUser(
            dbFile: dbFile,
            oldKey: kek,
            authService: authService,
            store: store,
            config: config,
          );

          if (dek != null) {
            // Migration succeeded — save bootstrap and cache DEK
            final wrapped = await authService.wrapStorageKey(dek: dek, kek: kek);
            await EncryptedDbBootstrap.save(
              saltHex: config.saltHex,
              hashHex: config.hashHex,
              wrappedDekHex: wrapped.ciphertextHex,
              wrappedNonceHex: wrapped.nonceHex,
              wrappedTagHex: wrapped.tagHex,
              hint: config.passwordHint,
            );
            ref.invalidate(masterPasswordConfigProvider);
            masterKey = dek;
            migrationMessage = 'Tu base de datos fue encriptada correctamente.';
          } else {
            // Migration failed — fall back to old behavior
            masterKey = kek;
            migrationFailed = true;
          }
        } else if (config != null && hasDek) {
          final dek = await authService.unwrapStorageKey(
            payload: EncryptionPayload(
              ciphertextHex: config.encryptedStorageKeyHex!,
              nonceHex: config.encryptedStorageKeyNonceHex ?? '',
              tagHex: config.encryptedStorageKeyTagHex ?? '',
            ),
            kek: kek,
          );
          masterKey = dek;
        } else {
          masterKey = kek;
        }
      }

      ref.read(masterPasswordProvider.notifier).setMasterPassword(masterKey);

      if (!context.mounted) return;

      // Show migration feedback before unlocking
      if (migrationMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(migrationMessage),
            duration: const Duration(seconds: 4),
          ),
        );
      } else if (migrationFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo encriptar la base de datos. '
              'Los datos siguen protegidos por tu contraseña maestra.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }

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
