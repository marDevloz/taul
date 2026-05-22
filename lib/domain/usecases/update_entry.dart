import 'package:taul/core/errors/failures.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';

class UpdateEntry {
  final IEntryRepository _repository;

  UpdateEntry({required IEntryRepository repository}) : _repository = repository;

  Future<Entry> call(Entry existing, {String? title, String? content, List<String>? tags, Map<String, String>? metadata}) async {
    final updated = existing.copyWith(
      title: title?.trim(),
      content: content?.trim(),
      tags: tags,
      metadata: metadata,
      updatedAt: DateTime.now(),
      version: existing.version + 1,
    );
    return _repository.update(updated);
  }
}
