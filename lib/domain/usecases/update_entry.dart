import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';

class UpdateEntry {
  final IEntryRepository _repository;

  UpdateEntry({required IEntryRepository repository}) : _repository = repository;

  Future<Entry> call(
    Entry existing, {
    String? title,
    String? content,
    List<String>? tags,
    Map<String, String>? metadata,
    String? secret,
    EntryType? type,
  }) async {
    final updated = existing.copyWith(
      title: title?.trim() ?? existing.title,
      content: content?.trim() ?? existing.content,
      tags: tags ?? existing.tags,
      metadata: metadata ?? existing.metadata,
      secret: secret,
      type: type ?? existing.type,
      updatedAt: DateTime.now(),
      version: existing.version + 1,
    );
    return _repository.update(updated);
  }
}
