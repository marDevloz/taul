import 'package:flutter/material.dart';

/// Dialog for entering an export passphrase.
///
/// Returns the passphrase string if confirmed, or null if cancelled.
class ExportPassphraseDialog extends StatefulWidget {
  const ExportPassphraseDialog({super.key});

  @override
  State<ExportPassphraseDialog> createState() => _ExportPassphraseDialogState();
}

class _ExportPassphraseDialogState extends State<ExportPassphraseDialog> {
  final _passphraseCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassphrase = true;
  String? _error;

  @override
  void dispose() {
    _passphraseCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _onConfirm() {
    final passphrase = _passphraseCtrl.text;
    final confirm = _confirmCtrl.text;

    if (passphrase.isEmpty) {
      setState(() => _error = 'Ingresá una contraseña');
      return;
    }
    if (passphrase.length < 8) {
      setState(() => _error = 'Mínimo 8 caracteres');
      return;
    }
    if (passphrase != confirm) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }

    Navigator.pop(context, passphrase);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Contraseña de exportación'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Creá una contraseña para cifrar la exportación. '
            'Es independiente de tu contraseña maestra.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passphraseCtrl,
            obscureText: _obscurePassphrase,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              hintText: 'Mínimo 8 caracteres',
              errorText: _error,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassphrase
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
                onPressed: () =>
                    setState(() => _obscurePassphrase = !_obscurePassphrase),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _confirmCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Confirmar contraseña',
            ),
            onSubmitted: (_) => _onConfirm(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _onConfirm,
          child: const Text('Cifrar y exportar'),
        ),
      ],
    );
  }
}
