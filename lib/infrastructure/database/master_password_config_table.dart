import 'package:drift/drift.dart';

class MasterPasswordConfig extends Table {
  IntColumn get id => integer().clientDefault(() => 1)();
  TextColumn get passwordHashArgon2 => text()();
  TextColumn get saltHex => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
