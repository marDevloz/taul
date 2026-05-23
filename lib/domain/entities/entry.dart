import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:taul/domain/entities/entry_type.dart';

part 'entry.freezed.dart';
part 'entry.g.dart';

@freezed
class Entry with _$Entry {
  const Entry._();
  const factory Entry({
    required String id,
    required EntryType type,
    required String title,
    required String content,
    @Default({}) Map<String, String> metadata,
    @Default([]) List<String> tags,
    String? topicKey,
    String? secret,
    @Default(false) bool requiresAuth,
    String? encryptedSecret,
    String? cipherNonce,
    String? cipherTag,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(1) int version,
    DateTime? deletedAt,
  }) = _Entry;

  factory Entry.fromJson(Map<String, dynamic> json) => _$EntryFromJson(json);

  bool get isDeleted => deletedAt != null;
  bool get isProtected => requiresAuth;
}
