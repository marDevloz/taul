import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';

class SearchEntries {
  final IEntryRepository _repository;

  SearchEntries({required IEntryRepository repository}) : _repository = repository;

  Future<List<Entry>> call(String query, {int limit = 100}) {
    if (query.trim().isEmpty) {
      return Future.value([]);
    }
    return _repository.search(query.trim(), limit: limit);
  }
}
