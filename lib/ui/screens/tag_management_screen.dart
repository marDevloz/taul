import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:taul/domain/entities/tag_setting.dart';
import 'package:taul/shared/tag_palette.dart';
import 'package:taul/ui/providers/color_providers.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/providers/tag_settings_providers.dart';
import 'package:taul/ui/screens/credential_protection_controller.dart';
import 'package:taul/ui/widgets/palette_picker.dart';

class TagManagementScreen extends ConsumerStatefulWidget {
  const TagManagementScreen({super.key});

  @override
  ConsumerState<TagManagementScreen> createState() =>
      _TagManagementScreenState();
}

class _TagManagementScreenState extends ConsumerState<TagManagementScreen> {
  final Set<String> _selectedTags = {};

  bool get _isSelectionMode => _selectedTags.isNotEmpty;

  void _toggleSelection(String tagName) {
    setState(() {
      if (_selectedTags.contains(tagName)) {
        _selectedTags.remove(tagName);
      } else {
        _selectedTags.add(tagName);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedTags.clear());
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagSettingsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSelectionMode
              ? '${_selectedTags.length} seleccionado${_selectedTags.length == 1 ? '' : 's'}'
              : 'Gestionar etiquetas',
        ),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              )
            : null,
        actions: _isSelectionMode
            ? []
            : [
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Agregar etiqueta',
                  onPressed: () => _showAddTagDialog(context),
                ),
              ],
      ),
      body: Stack(
        children: [
          tagsAsync.when(
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
                        style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
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
                      _TagSettingTile(
                        setting: tag,
                        ref: ref,
                        isSystem: true,
                      ),
                  ],
                  // User tags section
                  if (userTags.isNotEmpty) ...[
                    _buildSectionHeader(context, 'Tags personalizados'),
                    for (final tag in userTags)
                      _TagSettingTile(
                        setting: tag,
                        ref: ref,
                        isSystem: false,
                        isSelected: _selectedTags.contains(tag.name),
                        isSelectionMode: _isSelectionMode,
                        onToggle: () => _toggleSelection(tag.name),
                      ),
                  ],
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
          if (_isSelectionMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _DeleteActionBar(
                selectedCount: _selectedTags.length,
                onDelete: _showBatchDeleteConfirmation,
                onCancel: _clearSelection,
              ),
            ),
        ],
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

  Future<void> _showAddTagDialog(BuildContext context) async {
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

  Future<void> _showBatchDeleteConfirmation() async {
    final counts = ref.read(tagUsageCountProvider);
    int totalAffectedEntries = 0;
    for (final name in _selectedTags) {
      totalAffectedEntries += counts[name.toLowerCase()] ?? 0;
    }

    final count = _selectedTags.length;
    final entryLabel = totalAffectedEntries == 1 ? 'entrada' : 'entradas';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(count == 1 ? '¿Eliminar tag?' : '¿Eliminar tags?'),
        content: Text(
          count == 1
              ? 'Se eliminará 1 tag y se desvinculará de '
                  '$totalAffectedEntries $entryLabel.'
              : 'Se eliminarán $count tags y se desvincularán de '
                  '$totalAffectedEntries $entryLabel.',
        ),
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
      await _executeBatchDelete();
    }
    // If cancelled, stay in selection mode
  }

  Future<void> _executeBatchDelete() async {
    final deleteUseCase = ref.read(deleteTagSettingProvider);
    final removeTag = ref.read(removeTagFromEntriesProvider);
    final affectedEntryIds = <String>{};
    int successCount = 0;
    final totalCount = _selectedTags.length;

    for (final tagName in _selectedTags.toList()) {
      try {
        await deleteUseCase.call(tagName);
        final ids = await removeTag(tagName);
        affectedEntryIds.addAll(ids);
        successCount++;
      } catch (e) {
        Logger().e('Failed to delete tag $tagName', error: e);
      }
    }

    // Provider invalidation cascade
    ref.invalidate(tagSettingsListProvider);
    ref.invalidate(entryListProvider);
    for (final id in affectedEntryIds) {
      ref.invalidate(entryDetailProvider(id));
    }

    // Exit selection
    _clearSelection();

    // SnackBar
    if (!mounted) return;
    if (successCount == totalCount) {
      final label = totalCount == 1 ? 'tag' : 'tags';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$totalCount $label eliminados')),
      );
    } else if (successCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Se eliminaron $successCount de $totalCount tags'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron eliminar tags')),
      );
    }
  }
}

class _TagSettingTile extends ConsumerWidget {
  final TagSetting setting;
  final WidgetRef ref;
  final bool isSystem;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onToggle;

  const _TagSettingTile({
    required this.setting,
    required this.ref,
    this.isSystem = false,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onToggle,
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

    // User tag: selection mode or normal mode
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundColor: color,
            radius: 16,
            child: setting.isSecure
                ? const Icon(Icons.lock, size: 16, color: Colors.white)
                : null,
          ),
          if (isSelected)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(1),
                child: Icon(Icons.check_circle,
                    size: 14, color: Theme.of(context).colorScheme.primary),
              ),
            ),
        ],
      ),
      title: Text(setting.name),
      subtitle: setting.isSecure ? const Text('Requiere autenticación') : null,
      trailing: Switch(
        value: setting.isSecure,
        onChanged: (value) => _toggleSecure(context, value),
      ),
      onTap: isSelectionMode
          ? onToggle
          : () => _showRenameDialog(context),
      onLongPress: onToggle,
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
    ref.invalidate(tagSettingsMapProvider);
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
    final newName = result.trim();

    // Detección de merge: ya existe otra TagSetting con el nuevo nombre
    // (case-insensitive). El destino conserva su configuración.
    TagSetting? destination;
    final sourceLower = setting.name.toLowerCase();
    final newLower = newName.toLowerCase();
    final settings =
        ref.read(tagSettingsListProvider).valueOrNull ?? const <TagSetting>[];
    for (final s in settings) {
      if (s.name.toLowerCase() == sourceLower) continue;
      if (s.name.toLowerCase() == newLower) {
        destination = s;
        break;
      }
    }

    // El nombre canónico que las entradas llevarán: el del destino cuando se
    // mergea (para que coincida con la TagSetting sobreviviente), si no el
    // nuevo nombre tipeado.
    final canonicalName = destination?.name ?? newName;

    // Guard de downgrade: al mergear hacia un destino que no es seguro, se
    // pide confirmación explícita mostrando cuántas entradas pierden la
    // protección. Solo este sentido confirma; renombrar hacia un destino
    // seguro no requiere confirmación.
    if (destination != null && setting.isSecure && !destination.isSecure) {
      final counts = ref.read(tagUsageCountProvider);
      final affectedCount = counts[sourceLower] ?? 0;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Renombrar etiqueta?'),
          content: Text(
            affectedCount == 1
                ? '"$canonicalName" no requiere autenticación. '
                    '1 entrada dejará de estar protegida. ¿Continuar?'
                : '"$canonicalName" no requiere autenticación. '
                    '$affectedCount entradas dejarán de estar protegidas. '
                    '¿Continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    final deleteUseCase = ref.read(deleteTagSettingProvider);
    final saveUseCase = ref.read(saveTagSettingProvider);
    final renameTag = ref.read(renameTagOnEntriesProvider);

    try {
      final affectedEntryIds = await renameTag(setting.name, canonicalName);

      if (destination != null) {
        // Merge: el destino conserva su configuración, se elimina la fuente
        await deleteUseCase.call(setting.name);
      } else {
        await deleteUseCase.call(setting.name);
        await saveUseCase.call(
          newName,
          color: setting.color,
          isSecure: setting.isSecure,
          isSystem: setting.isSystem,
        );
      }

      // Invalidation cascade, igual que _executeBatchDelete
      ref.invalidate(tagSettingsListProvider);
      ref.invalidate(tagSettingsMapProvider);
      ref.invalidate(entryListProvider);
      for (final id in affectedEntryIds) {
        ref.invalidate(entryDetailProvider(id));
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Etiqueta renombrada')),
        );
      }
    } catch (e) {
      Logger().e('Failed to rename tag ${setting.name}', error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo renombrar la etiqueta')),
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

class _DeleteActionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  const _DeleteActionBar({
    required this.selectedCount,
    required this.onDelete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(
          top: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          // Selection count
          Expanded(
            child: Text(
              selectedCount == 1
                  ? '1 tag seleccionado'
                  : '$selectedCount tags seleccionados',
              style: theme.textTheme.titleSmall,
            ),
          ),
          const SizedBox(width: 8),
          // Cancel button
          IconButton(
            key: const Key('cancel_selection'),
            icon: const Icon(Icons.close),
            onPressed: onCancel,
            tooltip: 'Cancelar selección',
          ),
          // Delete button
          IconButton(
            key: const Key('delete_selected'),
            icon: const Icon(Icons.delete),
            color: theme.colorScheme.error,
            onPressed: onDelete,
            tooltip: 'Eliminar seleccionados',
          ),
        ],
      ),
    );
  }
}
