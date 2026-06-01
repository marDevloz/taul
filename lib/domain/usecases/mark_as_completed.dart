import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';

class MarkAsCompleted {
  final IEntryRepository _repository;

  const MarkAsCompleted({required IEntryRepository repository})
      : _repository = repository;

  Future<Entry> call(Entry entry) async {
    final updatedTags = entry.tags
        .where((t) => t != 'pendiente')
        .toList();

    if (!updatedTags.contains('completada')) {
      updatedTags.add('completada');
    }

    final updated = entry.copyWith(
      tags: updatedTags,
      completedAt: DateTime.now(),
      updatedAt: DateTime.now(),
      version: entry.version + 1,
    );

    return _repository.update(updated);
  }
}
