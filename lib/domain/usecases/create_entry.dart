import 'package:taul/core/errors/failures.dart';
import 'package:taul/domain/entities/entry.dart';
import 'package:taul/domain/entities/entry_type.dart';
import 'package:taul/domain/repositories/i_entry_repository.dart';
import 'package:uuid/uuid.dart';

class CreateEntry {
  final IEntryRepository _repository;
  final Uuid _uuid;

  const CreateEntry({
    required IEntryRepository repository,
    Uuid? uuid,
  })  : _repository = repository,
        _uuid = uuid ?? const Uuid();

  Future<Entry> call({
    required String title,
    required String content,
    EntryType? type,
    String? topicKey,
    String? secret,
    bool requiresAuth = false,
    String? encryptedSecret,
    String? cipherNonce,
    String? cipherTag,
    List<String> tags = const [],
    Map<String, String> metadata = const {},
  }) async {
    if (title.trim().isEmpty) {
      throw const ValidationFailure(message: 'Title cannot be empty');
    }

    final now = DateTime.now();
    final entry = Entry(
      id: _uuid.v4(),
      type: type ?? _inferType(title, content),
      title: title.trim(),
      content: content.trim(),
      tags: tags,
      topicKey: topicKey,
      secret: secret,
      requiresAuth: requiresAuth,
      encryptedSecret: encryptedSecret,
      cipherNonce: cipherNonce,
      cipherTag: cipherTag,
      metadata: metadata,
      createdAt: now,
      updatedAt: now,
    );

    return _repository.create(entry);
  }

  EntryType _inferType(String title, String content) {
    if (content.startsWith('!')) return EntryType.idea;
    if (content.contains(':')) return EntryType.glossary;
    if (content.startsWith('+')) return EntryType.credential;
    return EntryType.note;
  }
}
