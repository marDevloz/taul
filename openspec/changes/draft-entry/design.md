# Design: Draft Entry Persistence

## Technical Approach

Lightweight in-memory draft system for `CreateEntrySheet`. A `StateNotifier<EntryDraft?>` via Riverpod holds a single draft slot with save/restore/clear API. The sheet hooks into `initState` (restore) and `dispose` (auto-save). No infrastructure or domain layer changes — pure UI provider pattern.

## Architecture Decisions

| Decision | Option | Chosen | Rationale |
|----------|--------|--------|-----------|
| State mechanism | `StateNotifier<EntryDraft?>` | ✅ | Follows existing pattern (`AppLockNotifier`, `MasterPasswordNotifier`). Testable, exposes typed API, minimal ceremony |
| Storage layer | In-memory (ValueNotifier host) | ✅ | User constraint: no SharedPreferences for drafts. Encapsulated behind notifier — swap to disk later without touching sheet |
| Draft model | Freezed with JSON serialization | ✅ | Freezed is established in codebase. Including `toJson`/`fromJson` keeps door open for SharedPreferences without refactoring |
| Save trigger | `dispose()` + `_didSaveSuccessfully` flag | ✅ | Catches all dismiss routes (Cancel button, back gesture, swipe). Flag prevents double-save after successful submit |

### Key divergence from proposal

The proposal specifies `SharedPreferences` persistence. Per current constraint, draft storage is **in-memory only**. The `EntryDraftNotifier` encapsulates storage — moving to SharedPreferences later requires changing only the notifier body, not the sheet.

## Data Model

```dart
@freezed
class EntryDraft with _$EntryDraft {
  const factory EntryDraft({
    required String title,          // _titleCtrl.text
    required String content,        // Delta JSON from RichTextEditor
    required String tags,           // _tagsCtrl.text (comma-separated raw)
    EntryType? manualType,          // null = auto-detect from content
  }) = _EntryDraft;

  factory EntryDraft.fromJson(Map<String, dynamic> json) =>
      _$EntryDraftFromJson(json);
}
```

## Provider Structure

```
entryDraftProvider
  └─ StateNotifierProvider<EntryDraftNotifier, EntryDraft?>
       ├─ save(EntryDraft) → state
       ├─ restore() → state    (read via ref.read)
       └─ clear() → null
```

Created as a top-level provider in `lib/ui/providers/entry_draft_provider.dart`. No dependencies on other providers — standalone.

## Data Flow

```
                     ┌─────────────────────┐
                     │  EntryDraftNotifier  │
                     │  (in-memory state)  │
                     └──────┬──────┬───────┘
                      save  │  │   read/clear
                   ┌────────┘  └──────────┐
                   ▼                      ▼
     ┌─────────────────────┐   ┌───────────────────┐
     │  CreateEntrySheet   │   │ CreateEntrySheet  │
     │  dispose()          │   │ initState()       │
     │  (auto-save draft)  │   │ (restore draft)   │
     └─────────────────────┘   └───────────────────┘
```

**Open flow (restore):**
```
sheet.open → initState → ref.read(entryDraftProvider)
  → if draft != null → populate _titleCtrl, _tagsCtrl, _richContent, _manualType
  → build() passes _richContent to RichTextEditor(initialContent: ...)
```

**Close flow (save):**
```
user dismisses → dispose()
  → if _didSaveSuccessfully → skip (draft already cleared after save)
  → elif any field non-empty → ref.read(entryDraftProvider.notifier).save(...)
  → else → ref.read(entryDraftProvider.notifier).clear()
```

**Save flow (clear):**
```
user taps Save → _save() succeeds
  → _didSaveSuccessfully = true
  → ref.read(entryDraftProvider.notifier).clear()
  → Navigator.pop(context)
  → dispose() runs but skips draft save (flag is true)
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/ui/providers/entry_draft_provider.dart` | Create | `EntryDraft` freezed model + `EntryDraftNotifier` + provider |
| `lib/ui/screens/create_entry_sheet.dart` | Modify | `initState` restoration, `dispose` auto-save, `_didSaveSuccessfully` guard, pass `_richContent` to `RichTextEditor.initialContent` |
| `test/ui/providers/entry_draft_provider_test.dart` | Create | Unit tests for notifier operations |
| `test/ui/screens/create_entry_sheet_test.dart` | Create | Widget test for draft lifecycle integration |

## Interfaces / Contracts

```dart
// EntryDraftNotifier public API
class EntryDraftNotifier extends StateNotifier<EntryDraft?> {
  EntryDraftNotifier() : super(null); // null = no draft

  void save(EntryDraft draft) => state = draft;
  void clear() => state = null;
}

final entryDraftProvider =
    StateNotifierProvider<EntryDraftNotifier, EntryDraft?>((ref) {
  return EntryDraftNotifier();
});
```

## Modify CreateEntrySheet — key changes

**`initState`** — restore draft:
```dart
@override
void initState() {
  super.initState();
  final draft = ref.read(entryDraftProvider);
  if (draft != null) {
    _titleCtrl.text = draft.title;
    _tagsCtrl.text = draft.tags;
    _richContent = draft.content;
    _manualType = draft.manualType;
    _detectedType = _detectTypePure(draft.content); // pure computation
  }
}
```

**New field**: `var _didSaveSuccessfully = false;`

**`_save()`** — on success, set flag and clear draft:
```dart
_didSaveSuccessfully = true;
ref.read(entryDraftProvider.notifier).clear();
```

**`dispose()`** — auto-save draft:
```dart
@override
void dispose() {
  if (!_didSaveSuccessfully) {
    final hasContent = _titleCtrl.text.isNotEmpty ||
        _richContent.isNotEmpty ||
        _tagsCtrl.text.isNotEmpty;
    if (hasContent) {
      ref.read(entryDraftProvider.notifier).save(EntryDraft(
        title: _titleCtrl.text,
        content: _richContent,
        tags: _tagsCtrl.text,
        manualType: _manualType,
      ));
    } else {
      ref.read(entryDraftProvider.notifier).clear();
    }
  }
  _titleCtrl.dispose();
  _tagsCtrl.dispose();
  super.dispose();
}
```

**`build()`** — pass restored content:
```dart
RichTextEditor(
  initialContent: _richContent,  // was ''
  onChanged: (v) => setState(() { ... }),
),
```

## Testing Strategy

| Layer | What | How |
|-------|------|-----|
| Unit — Notifier | save/restore/clear state transitions | Create `ProviderContainer` with `entryDraftProvider`, assert state after each operation |
| Unit — Notifier | Initial state is null | Assert `state` is null before any operation |
| Widget — Sheet | Restore draft on open | Pump `CreateEntrySheet` with overridden `entryDraftProvider`, verify `TextField` values and `RichTextEditor` content |
| Widget — Sheet | Save draft on dismiss | Pump sheet, type content, close (via `Navigator.pop`), read provider to verify draft saved |
| Widget — Sheet | Clear draft on save | Pump sheet with draft override, trigger save, verify provider state is null after |
| Widget — Sheet | No draft on empty dismiss | Pump sheet, close without typing, verify provider state is null |
| Widget — Sheet | Skip draft after save | Pump sheet, save, verify `dispose` does not overwrite cleared draft |

## Open/Closed Principle

The `EntryDraftNotifier` encapsulates all storage logic behind three stable methods: `save`, `restore`, `clear`. `CreateEntrySheet` depends on this interface, not on storage internals.

**Future extensions without modifying `CreateEntrySheet`:**
- **Persistent drafts**: Replace in-memory state with `SharedPreferences` reads/writes inside the notifier. Provider signature unchanged.
- **Multiple draft slots**: Add `slotId` to `EntryDraft` model and index by ID in the notifier. Sheet calls same API.
- **Auto-save while typing**: Add a timer-based listener in the sheet (or a separate notifier wrapper) — the draft provider stays the same.

## Migration / Rollback

No migration required. Draft system is in-memory — clearing state on next app start is automatic. Rollback: revert `create_entry_sheet.dart` and delete `entry_draft_provider.dart`. Stale provider state is garbage collected with ProviderContainer.

## Open Questions

None.
