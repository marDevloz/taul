import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';

class UpdateEntryTagsColors {
  final IEntryRepository _repository;

  const UpdateEntryTagsColors({required IEntryRepository repository})
      : _repository = repository;

  Future<void> call(Entry entry, Map<String, String> tagsColors) {
    return _repository.updateTagsColors(entry.id, tagsColors);
  }
}
