import 'package:taul/domain/entities/tag_setting.dart';
import 'package:taul/domain/repositories/i_tag_settings_repository.dart';

class GetTagSettings {
  final ITagSettingsRepository _repository;

  GetTagSettings({required ITagSettingsRepository repository})
      : _repository = repository;

  Future<List<TagSetting>> call() => _repository.getAll();
}
