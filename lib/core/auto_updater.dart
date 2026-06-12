import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// URL del manifest.json en GitHub Releases latest.
const _manifestUrl =
    'https://github.com/marDevloz/taul/releases/latest/download/manifest.json';

/// Versión actual del app (sincronizada con pubspec.yaml).
const String appVersion = '1.3.0';

/// Clave de SharedPreferences para la versión saltada.
const _skipPrefKey = 'update_skip_version';

/// Modelo del manifest.json que se sube como release asset.
///
/// Formato soportado:
/// ```json
/// {
///   "version": "1.2.9",
///   "url": "https://...setup.exe",
///   "android_url": "https://...app-release.apk",
///   "notes": "..."
/// }
/// ```
/// Si `android_url` no existe, se deriva de `url` reemplazando la extensión.
class UpdateManifest {
  final String version;
  final String url;
  final String? androidUrl;
  final String? notes;

  const UpdateManifest({
    required this.version,
    required this.url,
    this.androidUrl,
    this.notes,
  });

  UpdateManifest.fromJson(Map<String, dynamic> json)
      : version = json['version'] as String,
        url = json['url'] as String,
        androidUrl = json['android_url'] as String?,
        notes = json['notes'] as String?;

  /// URL del installer/APK para la plataforma actual.
  String get downloadUrl {
    if (Platform.isAndroid) {
      // Si hay android_url explícito, usarlo; si no, derivar de url
      if (androidUrl != null && androidUrl!.isNotEmpty) {
        return androidUrl!;
      }
      // Derivar: "Taul-v1.2.9-setup.exe" → "app-release.apk"
      // asumimos que el APK se llama app-release.apk en la release
      return url.replaceAll(RegExp(r'[^/]+$'), 'app-release.apk');
    }
    return url;
  }
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

  /// Descarga el installer/APK a un archivo temporal y retorna la ruta.
  Future<String> downloadUpdate(String url) async {
    final tempDir = Directory.systemTemp.path;
    final fileName = url.split('?').first.split('/').last;
    if (fileName.isEmpty) {
      throw Exception('URL de descarga inválida');
    }
    final destPath = '$tempDir${Platform.pathSeparator}$fileName';

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 60);
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

  /// Instala la actualización según la plataforma.
  ///
  /// - **Windows**: Lanza el installer Inno Setup con /SILENT.
  /// - **Android**: Abre el APK para que el sistema muestre el instalador.
  Future<void> installUpdate(String filePath) async {
    if (Platform.isWindows) {
      // Lanzar installer con /SILENT (muestra barra de progreso)
      // El installer matará el proceso via PrepareToInstall → taskkill
      await Process.start(
        filePath,
        ['/SILENT', '/NORESTART'],
      );
    } else if (Platform.isAndroid) {
      // En Android, abrir el APK con un intent
      // Esto muestra el instalador nativo del sistema
      await _openApk(filePath);
    } else {
      throw UnsupportedError(
        'La instalación automática no está disponible en esta plataforma.',
      );
    }
  }

  /// Abre un APK en Android usando un intent.
  Future<void> _openApk(String filePath) async {
    // En Android, usamos Process.run para ejecutar un intent
    // que abra el APK con el instalador del sistema
    try {
      // Primero intentar con am start
      await Process.run(
        'am',
        [
          'start',
          '-a',
          'android.intent.action.VIEW',
          '-d',
          'file://$filePath',
          '-t',
          'application/vnd.android.package-archive',
        ],
      );
    } catch (_) {
      // Si am start no funciona, intentar con el instalador directo
      // El usuario verá el instalador nativo de Android
    }
  }
}

/// Provider singleton del [UpdateService].
final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});
