import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';

class ToggleEntryTag {
  final IEntryRepository _repository;

  const ToggleEntryTag({required IEntryRepository repository})
      : _repository = repository;

  Future<Entry> call(Entry entry, String tag) async {
    final updatedTags = entry.tags.contains(tag)
        ? entry.tags.where((t) => t != tag).toList()
        : [...entry.tags, tag];

    final updated = entry.copyWith(
      tags: updatedTags,
      updatedAt: DateTime.now(),
      version: entry.version + 1,
    );

    return _repository.update(updated);
  }
}
