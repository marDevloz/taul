import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taul/infrastructure/security/master_password_store.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/screens/credential_protection_controller.dart';
import 'package:taul/ui/screens/master_password_setup_dialog.dart';
import 'package:taul/ui/widgets/delete_mp_dialog.dart';
import 'package:taul/ui/widgets/hint_edit_dialog.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(masterPasswordConfigProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
        _sectionHeader('Master Password'),
        _statusTile(context, ref, config, isConfigured),

        if (isConfigured) ...[
          if (config.passwordHint != null && config.passwordHint!.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: const Text('Hint'),
              subtitle: Text(config.passwordHint!),
            ),
          ListTile(
            leading: const Icon(Icons.vpn_key),
            title: const Text('Remaining backup codes'),
            subtitle: Text(
              '${config.backupCodeHashes?.length ?? 0} codes available',
            ),
          ),
          const Divider(),
          // Actions
          _actionTile(
            context,
            icon: Icons.lock_outline,
            title: 'Change Master Password',
            onTap: () => _changeMasterPassword(context, ref),
          ),
          _actionTile(
            context,
            icon: Icons.edit,
            title: 'Edit Hint',
            onTap: () => _editHint(context, ref, config.passwordHint),
          ),
          _actionTile(
            context,
            icon: Icons.refresh,
            title: 'Regenerate Backup Codes',
            onTap: () => _regenerateCodes(context, ref),
          ),
          const Divider(),
          // Danger Zone
          _sectionHeader('Danger Zone'),
          _actionTile(
            context,
            icon: Icons.delete_forever,
            title: 'Delete Master Password',
            textColor: Colors.red,
            onTap: () => _deleteMasterPassword(context, ref),
          ),
        ] else ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton.icon(
              icon: const Icon(Icons.lock),
              label: const Text('Set Up Master Password'),
              onPressed: () => _setupMasterPassword(context, ref),
            ),
          ),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
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
        color: isConfigured ? Colors.green : Colors.grey,
      ),
      title: Text(isConfigured ? 'Configured' : 'Not configured'),
      subtitle: Text(
        isConfigured
            ? 'Master password is active'
            : 'No master password has been set up',
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(title, style: textColor != null ? TextStyle(color: textColor) : null),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
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
        const SnackBar(content: Text('Master password created successfully')),
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
        const SnackBar(content: Text('Master password changed successfully')),
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
          const SnackBar(content: Text('Hint saved')),
        );
      }
    }
  }

  Future<void> _regenerateCodes(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate backup codes'),
        content: const Text(
          'This will invalidate all existing backup codes. '
          'New codes will be generated. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Regenerate'),
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
          const SnackBar(content: Text('Master password inválida')),
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
          const SnackBar(content: Text('Backup codes regenerated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error regenerating codes: $e')),
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
          title: const Text('New backup codes'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Save these codes in a secure place. '
                'They are your ONLY way to recover access if you forget your master password.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
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
                    label: const Text('Copy all'),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: codes.join('\n')));
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Codes copied to clipboard')),
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
                      'I saved my codes in a secure place',
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
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: confirmed ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Confirm'),
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
          const SnackBar(content: Text('Master password deleted')),
        );
      }
    }
  }
}
