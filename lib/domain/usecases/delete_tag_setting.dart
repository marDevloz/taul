import 'package:taul/domain/repositories/i_tag_settings_repository.dart';

class DeleteTagSetting {
  final ITagSettingsRepository _repository;

  DeleteTagSetting({required ITagSettingsRepository repository})
      : _repository = repository;

  Future<void> call(String name) => _repository.delete(name);
}
