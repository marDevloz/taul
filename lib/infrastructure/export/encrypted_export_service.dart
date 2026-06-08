import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/infrastructure/security/entry_auth_service.dart';

/// Encrypted export format — single JSON blob with encrypted payload.
///
/// Structure:
/// ```json
/// {
///   "version": 1,
///   "encrypted": true,
///   "saltHex": "...",
///   "nonceHex": "...",
///   "tagHex": "...",
///   "ciphertextHex": "..."
/// }
/// ```
class EncryptedExportService {
  EncryptedExportService({
    required EntryAuthService authService,
  }) : _authService = authService;

  final EntryAuthService _authService;

  /// Exports entries as an encrypted JSON blob.
  ///
  /// [passphrase] is used to derive an encryption key via Argon2id.
  /// Returns the encrypted JSON string.
  Future<String> exportEncrypted({
    required List<Entry> entries,
    required String passphrase,
  }) async {
    // 1. Serialize entries to JSON
    final plaintext = jsonEncode({
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'entryCount': entries.length,
      'entries': entries.map((e) => e.toJson()).toList(),
    });

    // 2. Derive key from passphrase
    final salt = _authService.generateSalt();
    final key = await _authService.deriveMasterKey(
      password: passphrase,
      salt: salt,
    );

    // 3. Encrypt with AES-256-GCM
    final algorithm = AesGcm.with256bits();
    final secretBox = await algorithm.encrypt(
      Uint8List.fromList(utf8.encode(plaintext)),
      secretKey: SecretKey(key),
    );

    // 4. Build encrypted envelope
    final envelope = {
      'version': 1,
      'encrypted': true,
      'saltHex': _authService.bytesToHex(salt),
      'nonceHex': _authService.bytesToHex(secretBox.nonce),
      'tagHex': _authService.bytesToHex(secretBox.mac.bytes),
      'ciphertextHex': _authService.bytesToHex(secretBox.cipherText),
    };

    return const JsonEncoder.withIndent('  ').convert(envelope);
  }

  /// Decrypts an encrypted export blob.
  ///
  /// [passphrase] is used to derive the decryption key via Argon2id.
  /// Returns the decrypted JSON string, or null if decryption fails.
  Future<String?> decryptExport({
    required String encryptedJson,
    required String passphrase,
  }) async {
    try {
      final envelope = jsonDecode(encryptedJson) as Map<String, dynamic>;

      if (envelope['encrypted'] != true) return null;

      final saltHex = envelope['saltHex'] as String;
      final nonceHex = envelope['nonceHex'] as String;
      final tagHex = envelope['tagHex'] as String;
      final ciphertextHex = envelope['ciphertextHex'] as String;

      // Derive key from passphrase
      final salt = _authService.hexToBytes(saltHex);
      final key = await _authService.deriveMasterKey(
        password: passphrase,
        salt: salt,
      );

      // Decrypt with AES-256-GCM
      final algorithm = AesGcm.with256bits();
      final secretBox = SecretBox(
        _authService.hexToBytes(ciphertextHex),
        nonce: _authService.hexToBytes(nonceHex),
        mac: Mac(_authService.hexToBytes(tagHex)),
      );

      final decrypted = await algorithm.decrypt(
        secretBox,
        secretKey: SecretKey(key),
      );

      return utf8.decode(decrypted);
    } catch (_) {
      return null;
    }
  }

  /// Opens a file picker and saves the encrypted export.
  ///
  /// Returns the saved file path, or null if cancelled.
  Future<String?> saveEncryptedToFile(
    String encryptedJson,
    BuildContext context,
  ) async {
    final now = DateTime.now();
    final defaultName =
        'taul-export-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.json';

    final outputPath = await FilePicker.saveFile(
      dialogTitle: 'Guardar exportación cifrada',
      fileName: defaultName,
      allowedExtensions: ['json'],
      type: FileType.custom,
    );

    if (outputPath == null) return null;

    await File(outputPath).writeAsString(encryptedJson);
    return outputPath;
  }

  /// Reads an encrypted export file and decrypts it.
  ///
  /// Returns the decrypted JSON string, or null if decryption fails.
  Future<String?> readAndDecrypt({
    required String filePath,
    required String passphrase,
  }) async {
    final encryptedJson = await File(filePath).readAsString();
    return decryptExport(
      encryptedJson: encryptedJson,
      passphrase: passphrase,
    );
  }
}
