import 'package:taul/domain/repositories/i_entry_repository.dart';

class EmptyTrash {
  final IEntryRepository _repository;

  EmptyTrash({required IEntryRepository repository}) : _repository = repository;

  Future<int> call() async {
    final entries = await _repository.list(includeDeleted: true);
    final trashed = entries.where((e) => e.deletedAt != null).toList();
    for (final entry in trashed) {
      await _repository.hardDelete(entry.id);
    }
    return trashed.length;
  }
}
