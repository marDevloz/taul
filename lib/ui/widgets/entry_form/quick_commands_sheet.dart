import 'package:flutter/material.dart';

/// A bottom sheet showing quick command syntax help for entry creation.
class QuickCommandsSheet {
  QuickCommandsSheet._();

  /// Shows the quick commands help bottom sheet.
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _QuickCommandsContent(),
    );
  }
}

class _QuickCommandsContent extends StatelessWidget {
  const _QuickCommandsContent();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Comandos rápidos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: controller,
                children: const [
                  QuickCommandTile(
                    prefix: '! ',
                    example: '!idea genial',
                    description: 'Crear idea',
                  ),
                  QuickCommandTile(
                    prefix: '[] ',
                    example: '[] Comprar leche',
                    description: 'Crear tarea (o múltiples líneas con [])',
                  ),
                  QuickCommandTile(
                    prefix: '',
                    example: 'Término: definición',
                    description: 'Crear glosario',
                  ),
                  QuickCommandTile(
                    prefix: '',
                    example: 'servicio*user*pass*url -#tag',
                    description: 'Crear credencial (opcional url y tags)',
                  ),
                  QuickCommandTile(
                    prefix: 'Título# ',
                    example: 'Mi título# contenido',
                    description: 'Título explícito para cualquier tipo',
                  ),
                  QuickCommandTile(
                    prefix: '-#',
                    example: 'texto -#tag1 -#tag2',
                    description: 'Agregar tags a cualquier entrada',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single quick command entry with a prefix, example, and description.
class QuickCommandTile extends StatelessWidget {
  final String prefix;
  final String example;
  final String description;

  const QuickCommandTile({
    super.key,
    required this.prefix,
    required this.example,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (prefix.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: Text(
                prefix,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  example,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
