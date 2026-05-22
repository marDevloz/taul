import 'package:taul/core/errors/failures.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';

class DeleteEntry {
  final IEntryRepository _repository;

  DeleteEntry({required IEntryRepository repository}) : _repository = repository;

  Future<void> call(String id) => _repository.softDelete(id);
}
