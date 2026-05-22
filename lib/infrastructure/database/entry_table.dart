import 'package:drift/drift.dart';

class EntriesTable extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get metadata => text()(); // JSON string
  TextColumn get tags => text()(); // JSON array string
  TextColumn? get topicKey => text().nullable()();
  TextColumn? get secret => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn? get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String? get tableName => 'entries';
}

class EntriesFtsTable extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  TextColumn get tags => text()();

  @override
  String? get tableName => 'entries_fts';

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get createSql => '''
    CREATE VIRTUAL TABLE entries_fts USING fts5(
      id UNINDEXED,
      title,
      content,
      tags,
      tokenize='unicode61'
    );
  ''';
}
