// dart run tools/check_db2.dart
import 'package:sqlite3/sqlite3.dart';
import 'dart:io';

void main() {
  final dbPath = r'C:\Users\Manuel\OneDrive\Documentos\taul.db';
  final db = sqlite3.open(dbPath);
  
  // Full entry data for protected entries
  final entries = db.select('''
    SELECT id, title, encrypted_secret, cipher_nonce, cipher_tag,
           length(encrypted_secret) as enc_len,
           length(cipher_nonce) as nonce_len,
           length(cipher_tag) as tag_len
    FROM entries 
    WHERE requires_auth = 1
    ORDER BY created_at ASC
  ''');
  
  for (final row in entries) {
    final enc = row['encrypted_secret'] as String? ?? '';
    final nonce = row['cipher_nonce'] as String? ?? '';
    final tag = row['cipher_tag'] as String? ?? '';
    
    // Validate hex
    bool validHex(String s) => RegExp(r'^[a-fA-F0-9]+$').hasMatch(s);
    final validEnc = validHex(enc);
    final validNonce = validHex(nonce);
    final validTag = validHex(tag);
    
    print('Entry: ${row['title']}');
    print('  encrypted_secret: "$enc" (len=${enc.length}, valid_hex=$validEnc)');
    print('  cipher_nonce:     "$nonce" (len=${nonce.length}, valid_hex=$validNonce)');
    print('  cipher_tag:       "$tag" (len=${tag.length}, valid_hex=$validTag)');
    print('');
  }

  // Check config details
  final config = db.select('''
    SELECT password_hash_argon2, salt_hex, 
           encrypted_storage_key, encrypted_storage_key_nonce, encrypted_storage_key_tag
    FROM master_password_config WHERE id = 1
  ''');
  if (config.isNotEmpty) {
    final row = config.first;
    print('=== Config details ===');
    print('hash: ${row['password_hash_argon2']}');
    print('salt: ${row['salt_hex']}');
    print('dek_cipher: ${row['encrypted_storage_key']}');
    print('dek_nonce:  ${row['encrypted_storage_key_nonce']}');
    print('dek_tag:    ${row['encrypted_storage_key_tag']}');
    
    // These should all be valid hex
    for (final key in ['password_hash_argon2', 'salt_hex', 'encrypted_storage_key', 'encrypted_storage_key_nonce', 'encrypted_storage_key_tag']) {
      final val = row[key] as String? ?? '';
      final isValid = RegExp(r'^[a-fA-F0-9]+$').hasMatch(val);
      print('  $key: valid_hex=$isValid');
    }
  }

  db.dispose();
}
