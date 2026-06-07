import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/domain/entities/entry_type.dart';

part 'entry_draft_provider.freezed.dart';

// ---------------------------------------------------------------------------
// EntryDraft model
// ---------------------------------------------------------------------------

@freezed
class EntryDraft with _$EntryDraft {
  const factory EntryDraft({
    required String title,
    required String content,
    required String tags,
    EntryType? manualType,
  }) = _EntryDraft;
}

// ---------------------------------------------------------------------------
// Notifier — manages a single draft slot
// ---------------------------------------------------------------------------

class EntryDraftNotifier extends StateNotifier<EntryDraft?> {
  EntryDraftNotifier() : super(null);

  void save(EntryDraft draft) {
    state = draft;
  }

  void clear() {
    state = null;
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final entryDraftProvider =
    StateNotifierProvider<EntryDraftNotifier, EntryDraft?>((ref) {
  return EntryDraftNotifier();
});
