import 'package:flutter/material.dart';

/// A simple dialog for editing the master password hint.
///
/// Pre-filled with [currentHint]. Returns the new hint text on save,
/// or an empty string if the user cleared the hint. Returns null if cancelled.
class HintEditDialog extends StatefulWidget {
  const HintEditDialog({super.key, this.currentHint = ''});

  final String currentHint;

  @override
  State<HintEditDialog> createState() => _HintEditDialogState();
}

class _HintEditDialogState extends State<HintEditDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentHint);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Pista'),
      content: TextField(
        controller: _controller,
        maxLength: 200,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Pista de contraseña',
          hintText: 'ej: nombre de mi primera mascota',
          helperText: 'Tu pista se guarda como texto plano',
          helperMaxLines: 2,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
