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
    String? secret,
    bool requiresAuth = false,
    String? encryptedSecret,
    String? cipherNonce,
    String? cipherTag,
    List<String> tags = const [],
    Map<String, String> tagsColors = const {},
    Map<String, String> metadata = const {},
  }) async {
    final now = DateTime.now();
    final effectiveType = type ?? _inferType(title, content);
    final effectiveTags = _buildTags(tags, effectiveType);
    final entry = Entry(
      id: _uuid.v4(),
      type: effectiveType,
      title: title.trim(),
      content: content.trim(),
      tags: effectiveTags,
      tagsColors: tagsColors,
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
    if (content.startsWith('!') && content.length > 1 && content[1] != ' ') {
      return EntryType.idea;
    }
    if (RegExp(r'\S\*\S').hasMatch(content)) return EntryType.credential;
    if (RegExp(r'\w:\S').hasMatch(content)) return EntryType.glossary;
    return EntryType.note;
  }

  List<String> _buildTags(List<String> tags, EntryType type) {
    if (type == EntryType.task && !tags.contains('pendiente')) {
      return [...tags, 'pendiente'];
    }
    return tags;
  }
}
