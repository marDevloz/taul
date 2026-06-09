import 'package:drift/drift.dart';

class Conflicts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entryId => text()();
  TextColumn get localVersion => text()();
  TextColumn get remoteVersion => text()();
  TextColumn get resolution => text().withDefault(const Constant('PENDING'))();
  TextColumn get peerDeviceId => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn? get resolvedAt => dateTime().nullable()();

  Set<Column> get indexes => {entryId, resolution};
}