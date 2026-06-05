import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/tag_setting.dart';
import 'package:taul/shared/tag_palette.dart';
import 'package:taul/ui/providers/color_providers.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/providers/tag_settings_providers.dart';
import 'package:taul/ui/screens/credential_protection_controller.dart';
import 'package:taul/ui/widgets/palette_picker.dart';

class TagManagementScreen extends ConsumerWidget {
  const TagManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(tagSettingsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar etiquetas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Agregar etiqueta',
            onPressed: () => _showAddTagDialog(context, ref),
          ),
        ],
      ),
      body: tagsAsync.when(
        data: (tags) {
          if (tags.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.label_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay etiquetas',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agregá una etiqueta con el botón +',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          final systemTags = tags.where((t) => t.isSystem).toList();
          final userTags = tags.where((t) => !t.isSystem).toList();

          return ListView(
            children: [
              // System tags section
              if (systemTags.isNotEmpty) ...[
                _buildSectionHeader(context, 'Tags del sistema'),
                for (final tag in systemTags)
                  _TagSettingTile(setting: tag, ref: ref, isSystem: true),
              ],
              // User tags section
              if (userTags.isNotEmpty) ...[
                _buildSectionHeader(context, 'Tags personalizados'),
                for (final tag in userTags)
                  _TagSettingTile(setting: tag, ref: ref, isSystem: false),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _showAddTagDialog(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    String? selectedColor;
    String? error;

    await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Nueva etiqueta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    errorText: error,
                  ),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) {
                    if (error != null) setLocalState(() => error = null);
                  },
                ),
                const SizedBox(height: 16),
                const Text('Color:', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 8),
                PalettePicker(
                  onColorSelected: (hex) {
                    setLocalState(
                      () => selectedColor = hex.isEmpty ? null : hex,
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  setLocalState(() => error = 'El nombre no puede estar vacío');
                  return;
                }
                final saveUseCase = ref.read(saveTagSettingProvider);
                await saveUseCase.call(name, color: selectedColor, isSystem: false);
                ref.invalidate(tagSettingsListProvider);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagSettingTile extends ConsumerWidget {
  final TagSetting setting;
  final WidgetRef ref;
  final bool isSystem;

  const _TagSettingTile({
    required this.setting,
    required this.ref,
    this.isSystem = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final color = setting.color != null ? parseHex(setting.color!) : TagPalette.defaultGrey;

    if (isSystem) {
      // System tag: lock icon, no delete, no rename, no secure toggle,
      // but color IS editable via tap
      return ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          radius: 16,
          child: const Icon(Icons.lock, size: 16, color: Colors.white),
        ),
        title: Text(setting.name),
        subtitle: const Text('Tag del sistema — tocar para cambiar color'),
        trailing: const Icon(Icons.palette_outlined, size: 20),
        onTap: () => _showColorPicker(context),
        onLongPress: null,
      );
    }

    // User tag: full CRUD
    return ListTile(
      leading: GestureDetector(
        onTap: () => _showColorPicker(context),
        child: CircleAvatar(
          backgroundColor: color,
          radius: 16,
          child: setting.isSecure
              ? const Icon(Icons.lock, size: 16, color: Colors.white)
              : null,
        ),
      ),
      title: Text(setting.name),
      subtitle: setting.isSecure
          ? const Text('Requiere autenticación')
          : const Text('Tocar círculo para cambiar color'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.palette_outlined, size: 20),
            tooltip: 'Color',
            onPressed: () => _showColorPicker(context),
          ),
          Switch(
            value: setting.isSecure,
            onChanged: (value) => _toggleSecure(context, value),
          ),
        ],
      ),
      onTap: () => _showRenameDialog(context),
      onLongPress: () => _showDeleteConfirmation(context),
    );
  }

  Future<void> _showColorPicker(BuildContext context) async {
    final defaultHex =
        TagPalette.systemTagDefaults[setting.name.toLowerCase()]?.hex;
    final selectedHex = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Color para "${setting.name}"'),
        content: PalettePicker(
          initialColor: setting.color != null && setting.color!.isNotEmpty
              ? parseHex(setting.color!)
              : null,
          onColorSelected: (hex) => Navigator.pop(ctx, hex),
        ),
      ),
    );

    if (selectedHex == null || !context.mounted) return;

    // For system tags, "sin color" reverts to the system default
    final finalHex = selectedHex.isEmpty
        ? (defaultHex ?? selectedHex)
        : selectedHex;
    final saveUseCase = ref.read(saveTagSettingProvider);
    await saveUseCase.call(
      setting.name,
      color: finalHex.isEmpty ? null : finalHex,
      isSystem: setting.isSystem,
    );
    ref.invalidate(tagSettingsListProvider);
  }

  Future<void> _showRenameDialog(BuildContext context) async {
    final ctrl = TextEditingController(text: setting.name);
    String? error;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
          title: const Text('Renombrar etiqueta'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(labelText: 'Nombre', errorText: error),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {
              if (error != null) setLocalState(() => error = null);
            },
            onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final newName = ctrl.text.trim();
                if (newName.isEmpty) {
                  setLocalState(() => error = 'El nombre no puede estar vacío');
                  return;
                }
                Navigator.pop(ctx, newName);
              },
              child: const Text('Renombrar'),
            ),
          ],
        ),
      ),
    );

    if (result == null || result == setting.name || !context.mounted) return;

    final deleteUseCase = ref.read(deleteTagSettingProvider);
    final saveUseCase = ref.read(saveTagSettingProvider);

    await deleteUseCase.call(setting.name);
    await saveUseCase.call(
      result,
      color: setting.color,
      isSecure: setting.isSecure,
      isSystem: setting.isSystem,
    );
    ref.invalidate(tagSettingsListProvider);
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar etiqueta'),
        content: Text('¿Eliminar la etiqueta "${setting.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final deleteUseCase = ref.read(deleteTagSettingProvider);
      await deleteUseCase.call(setting.name);
      ref.invalidate(tagSettingsListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Etiqueta "${setting.name}" eliminada')),
        );
      }
    }
  }

  Future<void> _toggleSecure(BuildContext context, bool newValue) async {
    // If enabling secure, require master password
    if (newValue) {
      final controller = ref.read(credentialProtectionControllerProvider);
      try {
        await controller.requireMasterKey(context);
      } on UserCancelledException {
        return;
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al verificar la contraseña maestra'),
            ),
          );
        }
        return;
      }
    }

    if (!context.mounted) return;

    final saveUseCase = ref.read(saveTagSettingProvider);
    await saveUseCase.call(
      setting.name,
      color: setting.color,
      isSecure: newValue,
      isSystem: setting.isSystem,
    );
    ref.invalidate(tagSettingsListProvider);
  }
}
