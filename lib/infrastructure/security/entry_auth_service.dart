import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class EncryptionPayload {
  const EncryptionPayload({
    required this.ciphertextHex,
    required this.nonceHex,
    required this.tagHex,
  });

  final String ciphertextHex;
  final String nonceHex;
  final String tagHex;
}

class BackupCodeResult {
  const BackupCodeResult({
    required this.plainCodes,
    required this.codeHashes,
  });

  final List<String> plainCodes;
  final List<String> codeHashes;
}

class EntryAuthService {
  EntryAuthService({
    AesGcm? cipher,
    Argon2id? argon2id,
  })  : _cipher = cipher ?? AesGcm.with256bits(),
        _argon2id = argon2id ??
            Argon2id(
              memory: 65536,
              iterations: 2,
              parallelism: 1,
              hashLength: 32,
            );

  final AesGcm _cipher;
  final Argon2id _argon2id;
  final _random = Random.secure();

  Future<Uint8List> deriveMasterKey({
    required String password,
    required Uint8List salt,
  }) async {
    final key = await _argon2id.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    final bytes = await key.extractBytes();
    return Uint8List.fromList(bytes);
  }

  Future<String> hashMasterPassword({
    required String password,
    required Uint8List salt,
  }) async {
    final key = await deriveMasterKey(password: password, salt: salt);
    return _toHex(key);
  }

  Future<bool> verifyMasterPassword({
    required String password,
    required Uint8List salt,
    required String expectedHashHex,
  }) async {
    final computed = await hashMasterPassword(password: password, salt: salt);
    return computed == expectedHashHex.toLowerCase();
  }

  Future<EncryptionPayload> encryptSecret({
    required String plaintext,
    required Uint8List masterKey,
  }) async {
    final nonce = _randomBytes(12);
    final secretKey = SecretKey(masterKey);
    final secretBox = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );

    return EncryptionPayload(
      ciphertextHex: _toHex(secretBox.cipherText),
      nonceHex: _toHex(secretBox.nonce),
      tagHex: _toHex(secretBox.mac.bytes),
    );
  }

  Future<String> decryptSecret({
    required EncryptionPayload payload,
    required Uint8List masterKey,
  }) async {
    final secretBox = SecretBox(
      _fromHex(payload.ciphertextHex),
      nonce: _fromHex(payload.nonceHex),
      mac: Mac(_fromHex(payload.tagHex)),
    );

    final clearBytes = await _cipher.decrypt(
      secretBox,
      secretKey: SecretKey(masterKey),
    );
    return utf8.decode(clearBytes);
  }

  Uint8List generateSalt() => _randomBytes(16);
  String bytesToHex(List<int> bytes) => _toHex(bytes);
  Uint8List hexToBytes(String hex) => _fromHex(hex);

  /// Generates a random 32-byte storage key (DEK).
  Uint8List generateStorageKey() => _randomBytes(32);

  /// Encrypts the DEK with the KEK using AES-256-GCM.
  /// Returns the EncryptionPayload containing ciphertext, nonce, and tag.
  Future<EncryptionPayload> wrapStorageKey({
    required Uint8List dek,
    required Uint8List kek,
  }) async {
    final nonce = _randomBytes(12);
    final secretKey = SecretKey(kek);
    final secretBox = await _cipher.encrypt(
      dek,
      secretKey: secretKey,
      nonce: nonce,
    );

    return EncryptionPayload(
      ciphertextHex: _toHex(secretBox.cipherText),
      nonceHex: _toHex(secretBox.nonce),
      tagHex: _toHex(secretBox.mac.bytes),
    );
  }

  /// Decrypts a wrapped DEK using the KEK.
  /// Returns the original DEK bytes.
  Future<Uint8List> unwrapStorageKey({
    required EncryptionPayload payload,
    required Uint8List kek,
  }) async {
    final secretBox = SecretBox(
      _fromHex(payload.ciphertextHex),
      nonce: _fromHex(payload.nonceHex),
      mac: Mac(_fromHex(payload.tagHex)),
    );

    final clearBytes = await _cipher.decrypt(
      secretBox,
      secretKey: SecretKey(kek),
    );
    return Uint8List.fromList(clearBytes);
  }

  /// Generates backup codes, each individually salted and hashed with Argon2id.
  ///
  /// Returns a [BackupCodeResult] containing:
  /// - [plainCodes]: the plain backup codes in XXXX-XXXX format (shown once)
  /// - [codeHashes]: stored hashes as `salt_hex:hash_hex` for each code
  Future<BackupCodeResult> generateBackupCodes({int count = 10}) async {
    final plainCodes = <String>[];
    final codeHashes = <String>[];

    for (var i = 0; i < count; i++) {
      final code = _generateBackupCode();
      final salt = _randomBytes(8);
      final hash = await hashMasterPassword(password: code, salt: salt);
      codeHashes.add('${_toHex(salt)}:$hash');
      plainCodes.add(code);
    }

    return BackupCodeResult(plainCodes: plainCodes, codeHashes: codeHashes);
  }

  String _generateBackupCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final buffer = StringBuffer();
    for (var i = 0; i < 8; i++) {
      if (i == 4) buffer.write('-');
      buffer.write(chars[_random.nextInt(chars.length)]);
    }
    return buffer.toString();
  }

  Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  String _toHex(List<int> bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  Uint8List _fromHex(String hex) {
    final sanitized = hex.replaceAll(' ', '').toLowerCase();
    final bytes = Uint8List(sanitized.length ~/ 2);
    for (var i = 0; i < sanitized.length; i += 2) {
      bytes[i ~/ 2] = int.parse(sanitized.substring(i, i + 2), radix: 16);
    }
    return bytes;
  }
}
