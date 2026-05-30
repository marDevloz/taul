import 'package:taul/domain/repositories/i_tag_settings_repository.dart';

class SaveTagSetting {
  final ITagSettingsRepository _repository;

  SaveTagSetting({required ITagSettingsRepository repository})
      : _repository = repository;

  Future<void> call(String name, {String? color, bool isSecure = false}) =>
      _repository.save(name, color: color, isSecure: isSecure);
}
