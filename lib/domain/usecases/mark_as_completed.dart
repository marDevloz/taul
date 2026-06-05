import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';

class MarkAsCompleted {
  final IEntryRepository _repository;

  const MarkAsCompleted({required IEntryRepository repository})
      : _repository = repository;

  Future<Entry> call(Entry entry) async {
    if (entry.completedAt != null) {
      // Unmark: restore 'pendiente', remove 'completada'
      final updatedTags = entry.tags
          .where((t) => t != 'completada')
          .toList();

      if (!updatedTags.contains('pendiente')) {
        updatedTags.add('pendiente');
      }

      return _repository.update(entry.copyWith(
        tags: updatedTags,
        completedAt: null,
        updatedAt: DateTime.now(),
        version: entry.version + 1,
      ));
    } else {
      // Mark as completed: remove 'pendiente', add 'completada'
      final updatedTags = entry.tags
          .where((t) => t != 'pendiente')
          .toList();

      if (!updatedTags.contains('completada')) {
        updatedTags.add('completada');
      }

      return _repository.update(entry.copyWith(
        tags: updatedTags,
        completedAt: DateTime.now(),
        updatedAt: DateTime.now(),
        version: entry.version + 1,
      ));
    }
  }
}
