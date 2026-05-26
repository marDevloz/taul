import 'package:flutter/material.dart';

/// Confirmation dialog for deleting the master password.
///
/// Shows a warning with the count of protected entries that would become
/// unrecoverable. Returns `true` if the user confirms deletion.
class DeleteMpDialog extends StatelessWidget {
  const DeleteMpDialog({super.key, this.protectedEntryCount = 0});

  final int protectedEntryCount;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
      title: const Text('¿Eliminar Contraseña Maestra?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Esto va a eliminar permanentemente tu configuración de '
            'contraseña maestra, incluyendo el hash, la pista y todos '
            'los códigos de respaldo.',
          ),
          const SizedBox(height: 12),
          Text(
            protectedEntryCount > 0
                ? _buildProtectedWarning(protectedEntryCount)
                : 'No hay entradas protegidas. Podés configurar una '
                    'nueva contraseña maestra en cualquier momento.',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: protectedEntryCount > 0 ? Colors.red : Colors.orange,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: const Text(
              'Esta acción NO se puede deshacer. Si tenés entradas '
              'protegidas, van a quedar permanentemente inaccesibles.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Eliminar'),
        ),
      ],
    );
  }

  String _buildProtectedWarning(int count) {
    return count == 1
        ? 'Hay 1 entrada protegida que va a quedar IRRECUPERABLE.'
        : 'Hay $count entradas protegidas que van a quedar IRRECUPERABLES.';
  }
}
