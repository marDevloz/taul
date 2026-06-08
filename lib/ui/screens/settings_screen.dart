import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taul/infrastructure/security/master_password_store.dart';
import 'package:taul/ui/providers/auto_lock_provider.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/providers/theme_provider.dart';
import 'package:taul/ui/screens/credential_protection_controller.dart';
import 'package:taul/ui/screens/master_password_setup_dialog.dart';
import 'package:taul/ui/widgets/delete_mp_dialog.dart';
import 'package:taul/ui/widgets/export_passphrase_dialog.dart';
import 'package:taul/ui/widgets/hint_edit_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(masterPasswordConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: configAsync.when(
        data: (config) => _buildBody(context, ref, config),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    MasterPasswordFullConfig? config,
  ) {
    final isConfigured = config != null &&
        config.encryptedStorageKeyHex != null &&
        config.encryptedStorageKeyHex!.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // ── Master Password Section ──
        _sectionHeader(context, 'Contraseña Maestra'),
        _statusTile(context, ref, config, isConfigured),

        if (isConfigured) ...[
          if (config.passwordHint != null && config.passwordHint!.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: const Text('Pista'),
              subtitle: Text(config.passwordHint!),
            ),
          ListTile(
            leading: const Icon(Icons.vpn_key),
            title: const Text('Códigos de respaldo restantes'),
            subtitle: Text(
              '${config.backupCodeHashes?.length ?? 0} códigos disponibles',
            ),
          ),
          const Divider(),
          // Actions
          _actionTile(
            context,
            icon: Icons.lock_outline,
            title: 'Cambiar Contraseña Maestra',
            onTap: () => _changeMasterPassword(context, ref),
          ),
          _actionTile(
            context,
            icon: Icons.edit,
            title: 'Editar Pista',
            onTap: () => _editHint(context, ref, config.passwordHint),
          ),
          _actionTile(
            context,
            icon: Icons.refresh,
            title: 'Regenerar Códigos de Respaldo',
            onTap: () => _regenerateCodes(context, ref),
          ),
          const Divider(),
          // ── Auto-lock Section ──
          _sectionHeader(context, 'Seguridad'),
          _appLockToggle(context, ref),
          _autoLockTile(context, ref),
          const Divider(),
          // ── Tema Section ──
          _sectionHeader(context, 'Tema'),
          _themeTile(context, ref),
          const Divider(),
          // ── Data Section ──
          _sectionHeader(context, 'Datos'),
          _actionTile(
            context,
            icon: Icons.file_download,
            title: 'Exportar datos',
            onTap: () => _exportData(context, ref),
          ),
          _actionTile(
            context,
            icon: Icons.file_upload,
            title: 'Importar datos',
            onTap: () => _importData(context, ref),
          ),
          const Divider(),
          // ── Tag Management Section ──
          _sectionHeader(context, 'Etiquetas'),
          _actionTile(
            context,
            icon: Icons.label,
            title: 'Gestionar etiquetas',
            subtitle: 'Crear, editar y eliminar etiquetas',
            onTap: () => context.push('/settings/tags'),
          ),
          _actionTile(
            context,
            icon: Icons.menu_book,
            title: 'Manual de usuario',
            subtitle: 'Guía rápida y referencia de funciones',
            onTap: () => context.push('/settings/manual'),
          ),
          _actionTile(
            context,
            icon: Icons.info_outline,
            title: 'Acerca de',
            subtitle: 'Versión, autor y tecnología',
            onTap: () => context.push('/settings/about'),
          ),
          const Divider(),
          // Danger Zone
          _sectionHeader(context, 'Zona de Peligro'),
          _actionTile(
            context,
            icon: Icons.delete_forever,
            title: 'Eliminar Contraseña Maestra',
            textColor: Colors.red,
            onTap: () => _deleteMasterPassword(context, ref),
          ),
        ] else ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton.icon(
              icon: const Icon(Icons.lock),
              label: const Text('Configurar Contraseña Maestra'),
              onPressed: () => _setupMasterPassword(context, ref),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _statusTile(
    BuildContext context,
    WidgetRef ref,
    MasterPasswordFullConfig? config,
    bool isConfigured,
  ) {
    return ListTile(
      leading: Icon(
        isConfigured ? Icons.check_circle : Icons.cancel,
        color: isConfigured ? Colors.green : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(isConfigured ? 'Configurada' : 'No configurada'),
      subtitle: Text(
        isConfigured
            ? 'La contraseña maestra está activa'
            : 'No se configuró una contraseña maestra',
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(title, style: textColor != null ? TextStyle(color: textColor) : null),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  // ── App Lock Toggle ──

  Widget _appLockToggle(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(appLockEnabledProvider);

    return SwitchListTile(
      secondary: const Icon(Icons.lock_outline),
      title: const Text('Bloqueo general'),
      subtitle: Text(enabled ? 'Pedir contraseña al iniciar' : 'Sin bloqueo al iniciar'),
      value: enabled,
      onChanged: (value) async {
        await ref.read(appLockEnabledProvider.notifier).setEnabled(value);
        if (value) {
          // If turning ON and MP is configured, lock immediately
          ref.read(appLockProvider.notifier).lock();
        } else {
          // If turning OFF, unlock immediately
          ref.read(appLockProvider.notifier).unlock();
        }
      },
    );
  }

  // ── Auto-lock ──

  static const _autoLockOptions = <(Duration, String)>[
    (Duration.zero, 'Nunca'),
    (Duration(minutes: 1), '1 minuto'),
    (Duration(minutes: 5), '5 minutos'),
    (Duration(minutes: 15), '15 minutos'),
    (Duration(minutes: 30), '30 minutos'),
  ];

  static const _defaultAutoLock = Duration(minutes: 5);

  Widget _autoLockTile(BuildContext context, WidgetRef ref) {
    final autoLock = ref.watch(autoLockProvider);
    final current = autoLock.duration;

    return ListTile(
      leading: const Icon(Icons.timer_outlined),
      title: const Text('Bloqueo automático'),
      subtitle: Text(_autoLockLabel(current)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => _showAutoLockDialog(context, ref),
    );
  }

  String _autoLockLabel(Duration d) {
    if (d == Duration.zero) return 'Nunca';
    final entry = _autoLockOptions.firstWhere(
      (o) => o.$1 == d,
      orElse: () => (_defaultAutoLock, ''),
    );
    return entry.$2;
  }

  Future<void> _showAutoLockDialog(BuildContext context, WidgetRef ref) async {
    final current = ref.read(autoLockProvider).duration;

    await showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Bloqueo automático'),
        children: [
          RadioGroup<Duration>(
            groupValue: current,
            onChanged: (d) {
              if (d == null) return;
              ref.read(autoLockProvider.notifier).setDuration(d);
              Navigator.pop(ctx);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final opt in _autoLockOptions)
                  RadioListTile<Duration>(
                    title: Text(opt.$2),
                    value: opt.$1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Theme ──

  static const _themeLabels = <ThemeMode, String>{
    ThemeMode.system: 'Sistema',
    ThemeMode.dark: 'Oscuro',
    ThemeMode.light: 'Claro',
  };

  Widget _themeTile(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);

    return ListTile(
      leading: const Icon(Icons.dark_mode_outlined),
      title: const Text('Tema'),
      subtitle: Text(_themeLabels[current] ?? 'Sistema'),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => _showThemeDialog(context, ref),
    );
  }

  Future<void> _showThemeDialog(BuildContext context, WidgetRef ref) async {
    final current = ref.read(themeModeProvider);

    await showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Tema'),
        children: [
          RadioGroup<ThemeMode>(
            groupValue: current,
            onChanged: (mode) {
              if (mode == null) return;
              switch (mode) {
                case ThemeMode.system:
                  ref.read(themeModeProvider.notifier).setSystem();
                case ThemeMode.dark:
                  ref.read(themeModeProvider.notifier).setDark();
                case ThemeMode.light:
                  ref.read(themeModeProvider.notifier).setLight();
              }
              Navigator.pop(ctx);
            },
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<ThemeMode>(
                  title: Text('Sistema'),
                  value: ThemeMode.system,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('Oscuro'),
                  value: ThemeMode.dark,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('Claro'),
                  value: ThemeMode.light,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Action handlers ──

  Future<void> _setupMasterPassword(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const MasterPasswordSetupDialog(isChange: false),
    );
    if (result == true && context.mounted) {
      ref.invalidate(masterPasswordConfigProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña maestra creada con éxito')),
      );
    }
  }

  Future<void> _changeMasterPassword(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const MasterPasswordSetupDialog(isChange: true),
    );
    if (result == true && context.mounted) {
      ref.invalidate(masterPasswordConfigProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña maestra cambiada con éxito')),
      );
    }
  }

  Future<void> _editHint(
    BuildContext context,
    WidgetRef ref,
    String? currentHint,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => HintEditDialog(currentHint: currentHint ?? ''),
    );
    if (result != null && context.mounted) {
      await ref.read(masterPasswordStoreProvider).saveHint(
            result.isEmpty ? null : result,
          );
      ref.invalidate(masterPasswordConfigProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pista guardada')),
        );
      }
    }
  }

  Future<void> _regenerateCodes(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerar códigos de respaldo'),
        content: const Text(
          'Esto va a invalidar todos los códigos de respaldo existentes. '
          'Se van a generar códigos nuevos. ¿Continuamos?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Regenerar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final authService = ref.read(entryAuthServiceProvider);
    final store = ref.read(masterPasswordStoreProvider);
    final controller = ref.read(credentialProtectionControllerProvider);

    // Require master key — prompts user, unwraps DEK
    final Uint8List dek;
    try {
      dek = await controller.requireMasterKey(context);
    } on UserCancelledException {
      return;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña maestra inválida')),
        );
      }
      return;
    }

    if (!context.mounted) return;

    try {
      // Generate new codes with DEK wraps
      final codesWithWraps =
          await authService.generateBackupCodesWithDekWraps(dek);
      final backupCodeDataJson = jsonEncode(
        codesWithWraps.entries.map((e) => e.toJson()).toList(),
      );

      // Preserve existing hash, salt, hint, and encrypted key
      final config = await store.readFull();

      await store.saveFull(
        hashHex: config!.hashHex,
        saltHex: config.saltHex,
        hint: config.passwordHint,
        backupCodeHashesJson: jsonEncode(codesWithWraps.codeHashes),
        backupCodeDataJson: backupCodeDataJson,
        encryptedStorageKeyHex: config.encryptedStorageKeyHex,
        encryptedStorageKeyNonceHex: config.encryptedStorageKeyNonceHex,
        encryptedStorageKeyTagHex: config.encryptedStorageKeyTagHex,
      );

      controller.clearCachedDek();
      ref.invalidate(masterPasswordConfigProvider);

      if (!context.mounted) return;

      final codesSaved =
          await _showCodesDialog(context, codesWithWraps.plainCodes);
      if (codesSaved && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Códigos de respaldo regenerados')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al regenerar códigos: $e')),
        );
      }
    }
  }

  Future<bool> _showCodesDialog(BuildContext context, List<String> codes) async {
    var confirmed = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Nuevos códigos de respaldo'),
          content: Column(
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
                    label: const Text('Copiar todo'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: codes.join('\n')));
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Códigos copiados al portapapeles')),
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
                    onChanged: (v) => setLocalState(() => confirmed = v ?? false),
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

  Future<void> _deleteMasterPassword(BuildContext context, WidgetRef ref) async {
    final countAsync = ref.read(protectedEntryCountProvider.future);

    if (!context.mounted) return;

    final protectedCount = await countAsync;
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteMpDialog(protectedEntryCount: protectedCount),
    );

    if (confirmed == true && context.mounted) {
      final store = ref.read(masterPasswordStoreProvider);
      await store.delete();
      ref.read(masterPasswordProvider.notifier).clearMasterPassword();
      ref.invalidate(masterPasswordConfigProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña maestra eliminada')),
        );
      }
    }
  }

  // ── Import / Export ──

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    // 0. Disclaimer dialog
    if (!context.mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exportar datos'),
        content: const Text(
          'Este archivo contiene todas tus entradas, '
          'cifrado con una contraseña que elegís ahora.\n\n'
          'Sin esa contraseña, el archivo es inútil.\n\n'
          'No compartas este archivo a menos que sea estrictamente necesario.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Entendido, exportar'),
          ),
        ],
      ),
    );
    if (proceed != true) return;

    // 1. Passphrase dialog
    if (!context.mounted) return;
    final passphrase = await showDialog<String>(
      context: context,
      builder: (_) => const ExportPassphraseDialog(),
    );
    if (passphrase == null || passphrase.isEmpty) return;

    // 2. Progress dialog
    if (!context.mounted) return;
    _showProgressDialog(context, 'Exportando datos...');

    try {
      // 3. Get all active entries
      final entries = await ref.read(entryListProvider.future);
      if (!context.mounted) return;

      // 4. Encrypt and generate JSON
      final encryptedExportService = ref.read(encryptedExportServiceProvider);
      final json = await encryptedExportService.exportEncrypted(
        entries: entries,
        passphrase: passphrase,
      );

      // 5. Dismiss progress
      if (context.mounted) Navigator.of(context).pop();

      // 6. Save file via FilePicker
      final savedPath = await encryptedExportService.saveEncryptedToFile(json, context);

      // 7. Snackbar
      if (!context.mounted) return;
      if (savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exportación cifrada guardada en $savedPath')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    }
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    if (!context.mounted) return;

    // 1. Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar datos'),
        content: const Text(
          'Esto va a agregar entradas al vault actual. '
          'Las entradas existentes con el mismo ID se van a saltar. '
          '¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Importar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    // 2. Progress dialog
    _showProgressDialog(context, 'Importando datos...');

    try {
      // 3. Import
      final importService = ref.read(importServiceProvider);
      final result = await importService.importFromFile(context);

      if (!context.mounted) return;

      // 4. Dismiss progress
      Navigator.of(context).pop();

      // 5. Invalidate entry list
      ref.invalidate(entryListProvider);

      // 6. Build result message
      final buffer = StringBuffer();
      buffer.write('Se importaron ${result.imported} entradas.');
      if (result.skipped > 0) {
        buffer.write(' ${result.skipped} se saltaron por duplicadas.');
      }
      if (result.hasErrors) {
        buffer.write(' ${result.errors.length} errores.');
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(buffer.toString()),
          duration: const Duration(seconds: 5),
        ),
      );

      // Show error details if any
      if (result.hasErrors && context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Errores de importación'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: result.errors.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    result.errors[i],
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al importar: $e')),
        );
      }
    }
  }

  void _showProgressDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(message),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
