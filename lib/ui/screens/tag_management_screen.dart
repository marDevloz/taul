import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/tag_setting.dart';
import 'package:taul/shared/tag_palette.dart';
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
          return ListView.builder(
            itemCount: tags.length,
            itemBuilder: (_, index) => _TagSettingTile(
              setting: tags[index],
              ref: ref,
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
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
                    setLocalState(() => selectedColor = hex);
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
                await saveUseCase.call(name, color: selectedColor);
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

  const _TagSettingTile({
    required this.setting,
    required this.ref,
  });

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final color = setting.color != null
        ? Color(int.parse(setting.color!.substring(1), radix: 16) + 0xFF000000)
        : TagPalette.defaultGrey;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color,
        radius: 16,
        child: setting.isSecure
            ? const Icon(Icons.lock, size: 16, color: Colors.white)
            : null,
      ),
      title: Text(setting.name),
      subtitle: setting.isSecure
          ? const Text('Requiere autenticación')
          : null,
      trailing: Switch(
        value: setting.isSecure,
        onChanged: (value) => _toggleSecure(context, value),
      ),
      onTap: () => _showRenameDialog(context),
      onLongPress: () => _showDeleteConfirmation(context),
    );
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
            decoration: InputDecoration(
              labelText: 'Nombre',
              errorText: error,
            ),
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
    await saveUseCase.call(result, color: setting.color, isSecure: setting.isSecure);
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
            const SnackBar(content: Text('Error al verificar la contraseña maestra')),
          );
        }
        return;
      }
    }

    if (!context.mounted) return;

    final saveUseCase = ref.read(saveTagSettingProvider);
    await saveUseCase.call(setting.name,
        color: setting.color, isSecure: newValue);
    ref.invalidate(tagSettingsListProvider);
  }
}
