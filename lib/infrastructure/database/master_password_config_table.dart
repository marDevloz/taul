import 'package:drift/drift.dart';

class MasterPasswordConfig extends Table {
  IntColumn get id => integer().clientDefault(() => 1)();
  TextColumn get passwordHashArgon2 => text()();
  TextColumn get saltHex => text()();
  TextColumn? get passwordHint => text().nullable()();
  TextColumn? get backupCodeHashes => text().nullable()();
  TextColumn? get backupCodeData => text().nullable()();
  TextColumn? get encryptedStorageKey => text().nullable()();
  TextColumn? get encryptedStorageKeyNonce => text().nullable()();
  TextColumn? get encryptedStorageKeyTag => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
