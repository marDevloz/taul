import 'package:drift/drift.dart';
import 'package:taul/infrastructure/database/app_database.dart';

class MasterPasswordRecord {
  const MasterPasswordRecord({
    required this.hashHex,
    required this.saltHex,
  });

  final String hashHex;
  final String saltHex;
}

class MasterPasswordStore {
  const MasterPasswordStore(this._database);

  final AppDatabase _database;

  Future<MasterPasswordRecord?> read() async {
    final rows = await _database.customSelect(
      'SELECT password_hash_argon2, salt_hex FROM master_password_config WHERE id = 1 LIMIT 1',
    ).get();

    if (rows.isEmpty) return null;
    final row = rows.first.data;
    return MasterPasswordRecord(
      hashHex: row['password_hash_argon2'] as String,
      saltHex: row['salt_hex'] as String,
    );
  }

  Future<void> save({
    required String hashHex,
    required String saltHex,
  }) async {
    await _database.customInsert(
      'INSERT INTO master_password_config (id, password_hash_argon2, salt_hex, created_at, updated_at) '
      'VALUES (1, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP) '
      'ON CONFLICT(id) DO UPDATE SET '
      'password_hash_argon2 = excluded.password_hash_argon2, '
      'salt_hex = excluded.salt_hex, '
      'updated_at = CURRENT_TIMESTAMP',
      variables: [
        Variable.withString(hashHex),
        Variable.withString(saltHex),
      ],
    );
  }
}
