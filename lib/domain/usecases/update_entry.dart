import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';

class UpdateEntry {
  final IEntryRepository _repository;

  const UpdateEntry({required IEntryRepository repository}) : _repository = repository;

  Future<Entry> call(
    Entry existing, {
    String? title,
    String? content,
    List<String>? tags,
    Map<String, String>? metadata,
    String? secret,
    bool? requiresAuth,
    String? encryptedSecret,
    String? cipherNonce,
    String? cipherTag,
    bool clearProtection = false,
    EntryType? type,
  }) async {
    final updated = existing.copyWith(
      title: title?.trim() ?? existing.title,
      content: content?.trim() ?? existing.content,
      tags: tags ?? existing.tags,
      metadata: metadata ?? existing.metadata,
      secret: secret,
      requiresAuth: clearProtection ? false : (requiresAuth ?? existing.requiresAuth),
      encryptedSecret: clearProtection ? null : (encryptedSecret ?? existing.encryptedSecret),
      cipherNonce: clearProtection ? null : (cipherNonce ?? existing.cipherNonce),
      cipherTag: clearProtection ? null : (cipherTag ?? existing.cipherTag),
      type: type ?? existing.type,
      updatedAt: DateTime.now(),
      version: existing.version + 1,
    );
    return _repository.update(updated);
  }
}
