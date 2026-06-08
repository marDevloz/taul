import 'package:shared_preferences/shared_preferences.dart';

/// Stores the DEK bootstrap information in SharedPreferences so the app can
/// determine if the DB is encrypted and unwrap the DEK _before_ opening the
/// database connection (solving the chicken-and-egg problem).
///
/// The wrapped DEK (encrypted with KEK) is safe to store in prefs because
/// an attacker would still need the master password to derive the KEK and
/// decrypt it.
class EncryptedDbBootstrap {
  const EncryptedDbBootstrap._();

  static const _keyDbEncrypted = 'db_encrypted';
  static const _keySaltHex = 'db_dek_salt_hex';
  static const _keyHashHex = 'db_dek_hash_hex';
  static const _keyWrappedHex = 'db_dek_wrapped_hex';
  static const _keyWrappedNonceHex = 'db_dek_wrapped_nonce_hex';
  static const _keyWrappedTagHex = 'db_dek_wrapped_tag_hex';
  static const _keyHint = 'db_dek_hint';

  /// Whether the database is encrypted.
  static Future<bool> isEncrypted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDbEncrypted) ?? false;
  }

  /// Returns the stored bootstrap info, or null if not encrypted.
  static Future<BootstrapInfo?> read() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_keyDbEncrypted) ?? false)) return null;

    final saltHex = prefs.getString(_keySaltHex);
    final hashHex = prefs.getString(_keyHashHex);
    final wrappedHex = prefs.getString(_keyWrappedHex);

    if (saltHex == null || hashHex == null || wrappedHex == null) {
      return null; // Corrupted state
    }

    return BootstrapInfo(
      saltHex: saltHex,
      hashHex: hashHex,
      wrappedDekHex: wrappedHex,
      wrappedNonceHex: prefs.getString(_keyWrappedNonceHex) ?? '',
      wrappedTagHex: prefs.getString(_keyWrappedTagHex) ?? '',
      hint: prefs.getString(_keyHint),
    );
  }

  /// Saves the bootstrap info when encrypting the database.
  static Future<void> save({
    required String saltHex,
    required String hashHex,
    required String wrappedDekHex,
    required String wrappedNonceHex,
    required String wrappedTagHex,
    String? hint,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDbEncrypted, true);
    await prefs.setString(_keySaltHex, saltHex);
    await prefs.setString(_keyHashHex, hashHex);
    await prefs.setString(_keyWrappedHex, wrappedDekHex);
    await prefs.setString(_keyWrappedNonceHex, wrappedNonceHex);
    await prefs.setString(_keyWrappedTagHex, wrappedTagHex);
    if (hint != null) {
      await prefs.setString(_keyHint, hint);
    }
  }

  /// Clears the bootstrap info (e.g., when decrypting the database).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDbEncrypted);
    await prefs.remove(_keySaltHex);
    await prefs.remove(_keyHashHex);
    await prefs.remove(_keyWrappedHex);
    await prefs.remove(_keyWrappedNonceHex);
    await prefs.remove(_keyWrappedTagHex);
    await prefs.remove(_keyHint);
  }
}

class BootstrapInfo {
  const BootstrapInfo({
    required this.saltHex,
    required this.hashHex,
    required this.wrappedDekHex,
    required this.wrappedNonceHex,
    required this.wrappedTagHex,
    this.hint,
  });

  final String saltHex;
  final String hashHex;
  final String wrappedDekHex;
  final String wrappedNonceHex;
  final String wrappedTagHex;
  final String? hint;
}
