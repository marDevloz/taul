import 'package:taul/domain/entities/tag_setting.dart';

abstract class ITagSettingsRepository {
  Future<List<TagSetting>> getAll();
  Future<TagSetting?> getByName(String name);
  Future<void> save(String name, {String? color, bool isSecure = false});
  Future<void> delete(String name);
  Future<void> updateColor(String name, String? color);
  Future<void> updateSecure(String name, bool isSecure);
}
