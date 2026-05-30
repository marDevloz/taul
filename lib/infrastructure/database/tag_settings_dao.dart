import 'package:drift/drift.dart';
import 'package:taul/infrastructure/database/app_database.dart';
import 'package:taul/infrastructure/database/tag_settings_table.dart';

part 'tag_settings_dao.g.dart';

@DriftAccessor(tables: [TagSettings])
class TagSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$TagSettingsDaoMixin {
  TagSettingsDao(AppDatabase db) : super(db);

  Future<List<TagSetting>> getAllTags() => select(tagSettings).get();

  Future<TagSetting?> getByName(String name) =>
      (select(tagSettings)..where((t) => t.name.equals(name)))
          .getSingleOrNull();

  Future<void> upsert(String name,
          {String? color, bool isSecure = false}) =>
      into(tagSettings).insertOnConflictUpdate(
        TagSettingsCompanion.insert(
          name: name,
          color: Value.absentIfNull(color),
          isSecure: Value(isSecure),
        ),
      );

  Future<void> deleteByName(String name) =>
      (delete(tagSettings)..where((t) => t.name.equals(name))).go();

  Future<void> updateColor(String name, String? color) =>
      (update(tagSettings)..where((t) => t.name.equals(name))).write(
        TagSettingsCompanion(
          color: color != null ? Value(color) : const Value<String?>(null),
        ),
      );

  Future<void> updateSecure(String name, bool isSecure) =>
      (update(tagSettings)..where((t) => t.name.equals(name))).write(
        TagSettingsCompanion(isSecure: Value(isSecure)),
      );
}
