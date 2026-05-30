// dart run tools/check_db.dart
import 'package:sqlite3/sqlite3.dart';
import 'dart:io';

void main() {
  final dbPath = r'C:\Users\Manuel\OneDrive\Documentos\taul.db';
  if (!File(dbPath).existsSync()) {
    print('DB not found at $dbPath');
    return;
  }

  try {
    final db = sqlite3.open(dbPath);
    
    // Check master_password_config
    print('=== master_password_config ===');
    final config = db.select('''
      SELECT id, password_hash_argon2, salt_hex, 
             length(encrypted_storage_key) as dek_len,
             length(encrypted_storage_key_nonce) as nonce_len,
             length(encrypted_storage_key_tag) as tag_len
      FROM master_password_config WHERE id = 1
    ''');
    if (config.isEmpty) {
      print('No config found');
    } else {
      final row = config.first;
      print('  id: ${row['id']}');
      print('  hash_argon2: ${row['password_hash_argon2']} (${(row['password_hash_argon2'] as String).length} chars)');
      print('  salt_hex: ${row['salt_hex']} (${(row['salt_hex'] as String).length} chars)');
      print('  dek length: ${row['dek_len']}');
      print('  nonce length: ${row['nonce_len']}');
      print('  tag length: ${row['tag_len']}');
    }

    // Check entries with protection
    print('\n=== Protected entries ===');
    final entries = db.select('''
      SELECT id, title, requires_auth, 
             encrypted_secret IS NOT NULL as has_enc,
             length(encrypted_secret) as enc_len,
             length(cipher_nonce) as nonce_len,
             length(cipher_tag) as tag_len
      FROM entries 
      WHERE requires_auth = 1 
         OR encrypted_secret IS NOT NULL
      ORDER BY created_at DESC
    ''');
    
    if (entries.isEmpty) {
      print('No protected entries');
    } else {
      for (final row in entries) {
        print('  ID: ${row['id']}');
        print('  Title: ${row['title']}');
        print('  requires_auth: ${row['requires_auth']}');
        print('  has_encrypted: ${row['has_enc']}');
        print('  enc_len: ${row['enc_len']} chars');
        print('  nonce_len: ${row['nonce_len']} chars');
        print('  tag_len: ${row['tag_len']} chars');
        print('');
      }
    }

    db.dispose();
  } catch (e) {
    print('Error: $e');
  }
}
