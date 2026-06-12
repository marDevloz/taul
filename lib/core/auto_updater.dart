import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// URL del manifest.json en GitHub Releases latest.
const _manifestUrl =
    'https://github.com/marDevloz/taul/releases/latest/download/manifest.json';

/// Versión actual del app (sincronizada con pubspec.yaml).
const String appVersion = '1.2.8';

/// Clave de SharedPreferences para la versión saltada.
const _skipPrefKey = 'update_skip_version';

/// Solo Windows soporta instalación automática (Inno Setup).
bool get _supportsAutoInstall => Platform.isWindows;

/// Modelo del manifest.json que se sube como release asset.
class UpdateManifest {
  final String version;
  final String url;
  final String? notes;

  const UpdateManifest({
    required this.version,
    required this.url,
    this.notes,
  });

  UpdateManifest.fromJson(Map<String, dynamic> json)
      : version = json['version'] as String,
        url = json['url'] as String,
        notes = json['notes'] as String?;
}

/// Service que maneja el chequeo de actualizaciones, descarga e instalación.
class UpdateService {
  /// Compara dos versiones semánticas (X.Y.Z).
  /// Ignora sufijos pre-release (e.g. "1.3.0-beta.1" → [1,3,0]).
  /// Retorna true si [remote] es más nueva que [current].
  bool _isNewer(String remote, String current) {
    int parseSegment(String s) {
      // Strip pre-release, build metadata, and v prefix
      // "v1" → "1", "0-beta" → "0", "3+build" → "3"
      var cleaned = s.split(RegExp(r'[-+]')).first;
      cleaned = cleaned.replaceFirst(RegExp(r'^v'), '');
      return int.tryParse(cleaned) ?? 0;
    }

    final rParts = remote.split('.').map(parseSegment).toList();
    final cParts = current.split('.').map(parseSegment).toList();

    final len = rParts.length < cParts.length ? rParts.length : cParts.length;
    for (int i = 0; i < len; i++) {
      final r = rParts[i];
      final c = cParts[i];
      if (r > c) return true;
      if (r < c) return false;
    }
    return rParts.length > cParts.length;
  }

  /// Fetch remoto del manifest.json.
  Future<UpdateManifest?> _fetchManifest() async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(Uri.parse(_manifestUrl));
      final response = await request.close();
      if (response.statusCode != 200) return null;

      final body = await response.transform(utf8.decoder).join();
      return UpdateManifest.fromJson(jsonDecode(body) as Map<String, dynamic>);
    } catch (_) {
      return null; // fail silencioso
    } finally {
      client.close(force: true);
    }
  }

  /// Retorna un [UpdateManifest] si hay una versión más nueva disponible
  /// (y no fue saltada por el usuario).
  Future<UpdateManifest?> checkForUpdate() async {
    final manifest = await _fetchManifest();
    if (manifest == null) return null;

    if (!_isNewer(manifest.version, appVersion)) return null;

    final prefs = await SharedPreferences.getInstance();
    final skipped = prefs.getString(_skipPrefKey);
    if (skipped == manifest.version) return null;

    return manifest;
  }

  /// Marca una versión como "saltada" para no volver a preguntar.
  Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_skipPrefKey, version);
  }

  /// Descarga el installer a un archivo temporal y retorna la ruta.
  /// Solo funciona en Windows — en otras plataformas lanza [UnsupportedError].
  Future<String> downloadInstaller(String url) async {
    if (!_supportsAutoInstall) {
      throw UnsupportedError(
        'La instalación automática solo está disponible en Windows.',
      );
    }

    final tempDir = Directory.systemTemp.path;
    final fileName = url.split('?').first.split('/').last;
    if (fileName.isEmpty) {
      throw Exception('URL de descarga inválida');
    }
    final destPath = '$tempDir${Platform.pathSeparator}$fileName';

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final file = File(destPath);
      try {
        await response.pipe(file.openWrite());
      } catch (_) {
        // Limpiar archivo parcial en caso de fallo mid-stream
        if (await file.exists()) {
          await file.delete();
        }
        rethrow;
      }

      return destPath;
    } finally {
      client.close(force: true);
    }
  }

  /// Lanza el installer en modo silencioso.
  ///
  /// El installer ejecuta `taskkill /f /im taul.exe` via BeforeInstall
  /// ANTES de reemplazar archivos. No necesitamos cerrar la app desde Dart.
  Future<void> installUpdate(String installerPath) async {
    if (!_supportsAutoInstall) {
      throw UnsupportedError(
        'La instalación automática solo está disponible en Windows.',
      );
    }

    // Lanzar installer con /SILENT (muestra barra de progreso)
    // El installer matará el proceso via BeforeInstall → taskkill
    await Process.start(
      installerPath,
      ['/SILENT', '/NORESTART'],
    );

    // No cerramos la app desde aquí — el installer se encarga.
    // Si el installer falla, el usuario puede cerrar manualmente.
  }
}

/// Provider singleton del [UpdateService].
final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});
