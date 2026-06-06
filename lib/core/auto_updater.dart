import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// URL del manifest.json en GitHub Releases latest.
const _manifestUrl =
    'https://github.com/marDevloz/taul/releases/latest/download/manifest.json';

/// Versión actual del app (sincronizada con pubspec.yaml).
const String appVersion = '1.1.1';

/// Clave de SharedPreferences para la versión saltada.
const _skipPrefKey = 'update_skip_version';

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
  /// Retorna true si [remote] es más nueva que [current].
  bool _isNewer(String remote, String current) {
    final rParts = remote.split('.').map(int.tryParse).toList();
    final cParts = current.split('.').map(int.tryParse).toList();

    final len = rParts.length < cParts.length ? rParts.length : cParts.length;
    for (int i = 0; i < len; i++) {
      final r = rParts[i] ?? 0;
      final c = cParts[i] ?? 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return rParts.length > cParts.length;
  }

  /// Fetch remoto del manifest.json.
  Future<UpdateManifest?> _fetchManifest() async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(Uri.parse(_manifestUrl));
      final response = await request.close();
      if (response.statusCode != 200) return null;

      final body = await response.transform(utf8.decoder).join();
      return UpdateManifest.fromJson(jsonDecode(body) as Map<String, dynamic>);
    } catch (_) {
      return null; // fail silencioso
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
  Future<String> downloadInstaller(String url) async {
    final tempDir = Directory.systemTemp.path;
    final fileName = url.split('/').last;
    final destPath = '$tempDir\\$fileName';

    final client = HttpClient();
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();

    final file = File(destPath);
    await file.create(recursive: true);
    await response.pipe(file.openWrite());

    return destPath;
  }

  /// Ejecuta el installer en modo silencioso.
  Future<void> installUpdate(String installerPath) async {
    await Process.run(
      installerPath,
      ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART'],
      runInShell: true,
    );
  }
}

/// Provider singleton del [UpdateService].
final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});
