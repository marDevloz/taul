import 'package:taul/domain/repositories/i_entry_repository.dart';

class RestoreEntry {
  final IEntryRepository _repository;

  RestoreEntry({required IEntryRepository repository}) : _repository = repository;

  Future<void> call(String id) async {
    final entry = await _repository.getById(id);
    final restored = entry.copyWith(deletedAt: null, updatedAt: DateTime.now());
    await _repository.update(restored);
  }
}
