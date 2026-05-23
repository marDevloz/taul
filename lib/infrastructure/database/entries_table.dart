import 'package:drift/drift.dart';

class Entries extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get metadata => text()();
  TextColumn get tags => text()();
  TextColumn? get topicKey => text().nullable()();
  TextColumn? get secret => text().nullable()();
  BoolColumn get requiresAuth => boolean().withDefault(const Constant(false))();
  TextColumn? get encryptedSecret => text().nullable()();
  TextColumn? get cipherNonce => text().nullable()();
  TextColumn? get cipherTag => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn? get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
