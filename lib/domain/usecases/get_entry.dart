import 'package:taul/core/errors/failures.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';

class GetEntry {
  final IEntryRepository _repository;

  GetEntry({required IEntryRepository repository}) : _repository = repository;

  Future<Entry> call(String id) => _repository.getById(id);
}
