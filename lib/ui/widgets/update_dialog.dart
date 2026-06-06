import 'package:flutter/material.dart';
import 'package:taul/core/auto_updater.dart';

/// Acción seleccionada por el usuario en el diálogo de actualización.
enum UpdateDialogAction { download, later, skip }

/// Muestra un diálogo preguntando si quiere descargar la nueva versión.
///
/// Retorna la acción elegida. El caller se encarga de ejecutarla.
Future<UpdateDialogAction?> showUpdateDialog(
  BuildContext context,
  UpdateManifest manifest,
) async {
  final theme = Theme.of(context);

  return showDialog<UpdateDialogAction>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          const Text('Nueva versión disponible'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Taúl v${manifest.version}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (manifest.notes != null && manifest.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Novedades:',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              manifest.notes!,
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          Text(
            '¿Querés descargar la nueva versión ahora?',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(ctx, UpdateDialogAction.skip),
          child: const Text('Saltar esta versión'),
        ),
        OutlinedButton(
          onPressed: () =>
              Navigator.pop(ctx, UpdateDialogAction.later),
          child: const Text('Más tarde'),
        ),
        FilledButton.icon(
          onPressed: () =>
              Navigator.pop(ctx, UpdateDialogAction.download),
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Descargar ahora'),
        ),
      ],
    ),
  );
}
