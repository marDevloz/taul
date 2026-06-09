import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:taul/domain/entities/conflict_resolution.dart';
import 'package:taul/domain/entities/entry.dart';

part 'conflict.freezed.dart';
part 'conflict.g.dart';

@freezed
class Conflict with _$Conflict {
  const Conflict._();
  @JsonSerializable(explicitToJson: true)
  const factory Conflict({
    required int id,
    required String entryId,
    required Entry localVersion,
    required Entry remoteVersion,
    @Default(ConflictResolution.pending) ConflictResolution resolution,
    required String peerDeviceId,
    required DateTime createdAt,
    DateTime? resolvedAt,
  }) = _Conflict;

  factory Conflict.fromJson(Map<String, dynamic> json) =>
      _$ConflictFromJson(json);
}