import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';

class ListEntries {
  final IEntryRepository _repository;

  ListEntries({required IEntryRepository repository}) : _repository = repository;

  Future<List<Entry>> call({EntryType? type, String? topicKey, bool includeDeleted = false}) {
    return _repository.list(type: type, topicKey: topicKey, includeDeleted: includeDeleted);
  }
}
