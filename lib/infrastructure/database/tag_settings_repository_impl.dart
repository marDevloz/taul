import 'package:taul/domain/entities/tag_setting.dart' as domain;
import 'package:taul/domain/repositories/i_tag_settings_repository.dart';
import 'package:taul/infrastructure/database/app_database.dart' as db;
import 'package:taul/infrastructure/database/tag_settings_dao.dart';

class TagSettingsRepositoryImpl implements ITagSettingsRepository {
  final TagSettingsDao _dao;

  const TagSettingsRepositoryImpl({required TagSettingsDao dao}) : _dao = dao;

  @override
  Future<List<domain.TagSetting>> getAll() async {
    final rows = await _dao.getAllTags();
    return rows.map(_toDomain).toList();
  }

  @override
  Future<domain.TagSetting?> getByName(String name) async {
    final row = await _dao.getByName(name);
    if (row == null) return null;
    return _toDomain(row);
  }

  @override
  Future<void> save(String name, {String? color, bool isSecure = false}) =>
      _dao.upsert(name, color: color, isSecure: isSecure);

  @override
  Future<void> delete(String name) => _dao.deleteByName(name);

  @override
  Future<void> updateColor(String name, String? color) =>
      _dao.updateColor(name, color);

  @override
  Future<void> updateSecure(String name, bool isSecure) =>
      _dao.updateSecure(name, isSecure);

  domain.TagSetting _toDomain(db.TagSetting row) => domain.TagSetting(
        name: row.name,
        color: row.color,
        isSecure: row.isSecure,
        createdAt: row.createdAt,
      );
}
