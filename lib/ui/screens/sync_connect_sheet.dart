import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:taul/infrastructure/sync/sync_client.dart';
import 'package:taul/ui/providers/sync_client_providers.dart';

/// Full-screen QR scanner page using flutter_zxing.
///
/// Returns the scanned text on success, or null if cancelled.
class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  bool _showScanner = false;

  @override
  void initState() {
    super.initState();
    // Delay showing the scanner slightly so the push transition completes
    // before the camera initializes.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _showScanner = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_showScanner)
            ReaderWidget(
              onScan: (Code code) {
                if (code.text != null && code.text!.isNotEmpty) {
                  Navigator.of(context).pop(code.text);
                }
              },
              onScanFailure: (_) {
                // Continue scanning — next frame will retry
              },
              codeFormat: Format.qrCode,
              showScannerOverlay: true,
              showFlashlight: true,
              showGallery: true,
              showToggleCamera: true,
              tryHarder: true,
              cropPercent: 0.6,
              scanDelay: const Duration(milliseconds: 500),
              scanDelaySuccess: const Duration(milliseconds: 1500),
              loading: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Iniciando cámara…',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ],
                ),
              ),
            )
          else
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Preparando cámara…',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),

          // Close button at top-left
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Helper text at the bottom
          const SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 24),
                child: Text(
                  'Enfocá el código QR',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
  bool _isUpdatingCode = false;

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
  }

  @override
  void dispose() {
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    // If we're programmatically updating the code, skip
    if (_isUpdatingCode) return;

    final url = _urlController.text.trim();
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasQuery) return;

    final code = uri.queryParameters['code'];
    if (code == null || !RegExp(r'^\d{6}$').hasMatch(code)) return;

    _isUpdatingCode = true;
    _codeController.text = code;
    _isUpdatingCode = false;
    setState(() {});
  }

  bool get _isValid {
    final url = _urlController.text.trim();
    final code = _codeController.text.trim();
    return url.isNotEmpty &&
        url != 'https://' &&
        !url.startsWith('http://') &&
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
      final peerCert = socket.peerCertificate;
      if (peerCert == null || peerCert.der.isEmpty) {
        await socket.close();
        throw const TlsFingerprintMissingException();
      }
      final fingerprint = peerCert.der.cast<int>();
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
    } on TlsFingerprintMissingException {
      _showError('Servidor sin certificado TLS — verificar URL');
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

  Future<void> _openQrScanner() async {
    final scannedText = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const _QrScannerPage(),
        fullscreenDialog: true,
      ),
    );

    if (scannedText == null || scannedText.isEmpty) return;
    if (!mounted) return;

    final uri = Uri.tryParse(scannedText.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      _showError('QR inválido — no se pudo extraer la URL');
      return;
    }

    // Rebuild URL with scheme + host:port (strip any path/query so it's clean)
    final port = uri.port > 0 ? ':${uri.port}' : '';
    final cleanUrl = '${uri.scheme}://${uri.host}$port';
    _urlController.text = cleanUrl;

    // Extract pairing code from query params
    final code = uri.queryParameters['code'];
    if (code != null && RegExp(r'^\d{6}$').hasMatch(code)) {
      _isUpdatingCode = true;
      _codeController.text = code;
      _isUpdatingCode = false;
    }

    setState(() {});
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
              decoration: InputDecoration(
                labelText: 'URL del servidor',
                hintText: 'https://192.168.1.x:54321',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Escanear QR',
                  onPressed: _isLoading ? null : _openQrScanner,
                ),
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
