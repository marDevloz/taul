import 'package:drift/drift.dart';

class TagSettings extends Table {
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();
  BoolColumn get isSecure => boolean().withDefault(const Constant(false))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {name};
}
