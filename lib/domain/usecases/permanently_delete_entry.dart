import 'package:taul/domain/repositories/i_entry_repository.dart';

class PermanentlyDeleteEntry {
  final IEntryRepository _repository;

  PermanentlyDeleteEntry({required IEntryRepository repository})
      : _repository = repository;

  Future<void> call(String id) => _repository.hardDelete(id);
}