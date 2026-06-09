import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:taul/domain/entities/entry.dart';

part 'sync_wire_format.freezed.dart';
part 'sync_wire_format.g.dart';

@JsonSerializable(explicitToJson: true)
@freezed
class SyncRequest with _$SyncRequest {
  const factory SyncRequest({
    required String deviceId,
    DateTime? lastSyncAt,
    @Default([]) List<Entry> entries,
  }) = _SyncRequest;

  factory SyncRequest.fromJson(Map<String, dynamic> json) =>
      _$SyncRequestFromJson(json);
}

@freezed
class SyncResponse with _$SyncResponse {
  const factory SyncResponse({
    required String deviceId,
    required int entriesReceived,
    required int conflictsCount,
    DateTime? serverLastSyncAt,
  }) = _SyncResponse;

  factory SyncResponse.fromJson(Map<String, dynamic> json) =>
      _$SyncResponseFromJson(json);
}

@freezed
class SyncErrorResponse with _$SyncErrorResponse {
  const factory SyncErrorResponse({
    required int code,
    required String message,
  }) = _SyncErrorResponse;

  factory SyncErrorResponse.fromJson(Map<String, dynamic> json) =>
      _$SyncErrorResponseFromJson(json);
}
