import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/infrastructure/sync/sync_client.dart';
import 'package:taul/ui/providers/sync_client_providers.dart';

/// Bottom sheet for connecting to a remote sync server.
///
/// Takes a remote URL and pairing code, then initiates a client sync.
class SyncConnectSheet extends ConsumerStatefulWidget {
  const SyncConnectSheet({super.key});

  @override
  ConsumerState<SyncConnectSheet> createState() => _SyncConnectSheetState();
}

class _SyncConnectSheetState extends ConsumerState<SyncConnectSheet> {
  final _urlController = TextEditingController(text: 'https://');
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _urlController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  bool get _isValid {
    final url = _urlController.text.trim();
    final code = _codeController.text.trim();
    return url.isNotEmpty &&
        url != 'https://' &&
        RegExp(r'^\d{6}$').hasMatch(code);
  }

  Future<void> _submit() async {
    if (!_isValid || _isLoading) return;
    setState(() => _isLoading = true);

    try {
      final urlStr = _urlController.text.trim();
      final code = _codeController.text.trim();

      // Normalize URL — add https:// if missing
      var input = urlStr;
      if (!input.startsWith('https://') && !input.startsWith('http://')) {
        input = 'https://$input';
      }
      final uri = Uri.parse(input);
      final host = uri.host;
      final port = uri.port == 0 ? 443 : uri.port;

      // Get TLS fingerprint from server (trust-on-first-use)
      final socket = await SecureSocket.connect(
        host,
        port,
        timeout: const Duration(seconds: 10),
        onBadCertificate: (_) => true,
      );
      final fingerprint = socket.peerCertificate?.der.cast<int>() ?? [];
      await socket.close();

      // Connect and sync
      final params = ConnectParams(
        host: host,
        port: port,
        fingerprint: fingerprint,
        pairingCode: code,
      );
      await ref.read(connectAndSyncProvider(params).future);

      if (mounted) Navigator.of(context).pop(true);
    } on PairingCodeRejectedException {
      _showError('Código de emparejamiento incorrecto');
    } on TlsFingerprintMismatchException {
      _showError('Certificado desconocido — reconectar');
    } on SocketException {
      _showError('Servidor no encontrado — verificar URL');
    } on TimeoutException {
      _showError('Conexión agotada — intentar de nuevo');
    } catch (e) {
      _showError('Error de conexión: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.sync, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Conectar a dispositivo',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // URL field
            TextField(
              controller: _urlController,
              onChanged: (_) => setState(() {}),
              enabled: !_isLoading,
              decoration: const InputDecoration(
                labelText: 'URL del servidor',
                hintText: 'https://192.168.1.x:54321',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              autofocus: true,
            ),
            const SizedBox(height: 12),

            // Pairing code field
            TextField(
              controller: _codeController,
              onChanged: (_) => setState(() {}),
              enabled: !_isLoading,
              decoration: const InputDecoration(
                labelText: 'Código de enlace',
                hintText: 'Código de 6 dígitos',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            const SizedBox(height: 8),

            // Submit button
            FilledButton(
              onPressed: (_isValid && !_isLoading) ? _submit : null,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Conectar'),
            ),
          ],
        ),
      ),
    );
  }
}
