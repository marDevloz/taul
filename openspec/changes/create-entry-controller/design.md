# Design: CreateEntryController

## Technical Approach

Extract all parsing, type-detection, content-formatting, and save-orchestration logic from `CreateEntrySheet` and `QuickAddSheet` into a `StateNotifier<CreateEntryState>` backed by a Riverpod `StateNotifierProvider`. Both sheets become thin UI shells that read state and call controller methods. The controller normalizes content to Delta JSON internally — QuickAddSheet's plain-text input converts to Delta JSON before delegation.

## Architecture Decisions

| Option | Tradeoff | Decision |
|--------|----------|----------|
| `StateNotifier` vs `ChangeNotifier` | Riverpod integration vs manual lifecycle | **StateNotifier** — matches `EntryDraftNotifier` / `AppLockNotifier` pattern in codebase |
| Freezed state vs raw fields | Boilerplate vs computed getters | **Freezed** — `effectiveType` / `isManual` as computed getters, automatic `==` / `copyWith` |
| `ProcessedContent` as Freezed vs Map | Type safety vs flexibility | **Freezed** — callers need explicit typed return from `processContentForType` |
| Controller takes `Ref` vs explicit deps | Convenience vs testability | **Explicit constructor params** — `CreateEntry`, `EntryDraftNotifier` injected; `Ref` used only for `entryListProvider.invalidate` in save |
| Single `detectTypeFromContent` for both sheets | One code path vs duplicated detection logic | **Single method** — QuickAddSheet wraps plain text in Delta JSON before calling; detection logic ported from CreateEntrySheet (more correct version) |

## State Model

```dart
// lib/ui/controllers/create_entry_controller.dart

@freezed
class CreateEntryState with _$CreateEntryState {
  const CreateEntryState._();

  const factory CreateEntryState({
    required String title,        // manual title field
    required String content,      // Delta JSON string
    required String tags,         // comma-separated manual tags
    EntryType? detectedType,      // auto-detected from content
    EntryType? manualType,        // user override via dropdown
    @Default(false) bool isSaving,
    String? error,
  }) = _CreateEntryState;

  /// Computed: manual overrides detected, falls back to note.
  EntryType get effectiveType => manualType ?? detectedType ?? EntryType.note;

  /// True when the user has explicitly set a type.
  bool get isManual => manualType != null;
}

@freezed
class ProcessedContent with _$ProcessedContent {
  const factory ProcessedContent({
    required String content,
    required Map<String, String> metadata,
    String? secret,
    @Default(false) bool requiresAuth,
    @Default([]) List<String> tags,
  }) = _ProcessedContent;
}
```

## Controller Methods

```dart
class CreateEntryController extends StateNotifier<CreateEntryState> {
  CreateEntryController({
    required CreateEntry createEntry,
    required EntryDraftNotifier draftNotifier,
    required Ref ref,              // for entryListProvider.invalidate
  }) : ...;

  // ── Public API ────────────────────────────────────────────────────────

  /// Updates [detectedType] from Delta JSON content.
  /// Logic ported from CreateEntrySheet._detectTypeFromContent:
  ///   1. Convert Delta → plain text
  ///   2. Check `!` (idea) BEFORE Title# split
  ///   3. Split Title#, check task marker, credential `\w+\*\w+\*\w+`, glossary `\w{2,}:(?!//)\s*\S`
  void detectTypeFromContent(String deltaJson);

  /// Pure — splits "Title# rest" at first `# ` boundary.
  /// Returns `(title: "", rest: raw)` if no marker found.
  static ({String title, String rest}) splitTitle(String plainText);

  /// Pure — delegates to RichTextHelper.extractTags.
  static ({String clean, List<String> tags}) extractTags(String plainText);

  /// Strips both the `Title# ` prefix and `-#tag` markers from Delta JSON.
  /// Order: strip title prefix FIRST, then tags (preserves Delta structure).
  static String stripTitleAndTags(
    String deltaJson, List<String> tags, String titlePrefix,
  );

  /// Formats body content according to EntryType rules:
  ///   - idea:       strip leading `!`
  ///   - glossary:   RichTextHelper.formatForGlossary(body) (returns Delta)
  ///   - credential: CredentialParser.parse, build metadata/secret/requiresAuth
  ///   - task:       stripTitleAndTags + strip task marker
  ///   - note:       stripTitleAndTags
  /// Falls back to note if credential parsing fails.
  /// Does NOT mutate state — side-effect-free transformation.
  ProcessedContent processContentForType(
    EntryType type, String body, String title, List<String> tags,
  );

  /// Full save orchestration — does NOT mutate state except `isSaving`/`error`:
  ///   1. Guard: early return if no content
  ///   2. Convert Delta → plain text, extractTags, splitTitle
  ///   3. Merge manual + extracted tags
  ///   4. Call processContentForType
  ///   5. Set isSaving = true
  ///   6. Call createEntry(...)
  ///   7. Clear draft, invalidate entryList, pop on success
  ///   8. On error: set isSaving = false, set error message
  Future<void> save();

  /// Resets state to initial (empty) values.
  void reset();

  /// Loads draft content into state.
  void loadDraft(EntryDraft draft);

  /// Sets manual type override.
  void setManualType(EntryType? type);
}
```

### Key Differences from Existing Inline Code

| Behavior | CreateEntrySheet (old) | Controller |
|----------|----------------------|------------|
| `_stripTitleAndTags` | Reads `_richContent` from local state | Explicit `deltaJson` parameter |
| Glossary formatting | `formatForGlossary(body)` only | Same call, but `body` already derived from plain-text extraction |
| QuickAddSheet glossary | Manual `indexOf(':')` split + inline title extraction | Ported into `processContentForType` glossary branch — extracts title from `:` if not provided |
| Error reporting | `ScaffoldMessenger.showSnackBar` directly | Sets `state.error` — widget reads and shows snackbar |
| Draft lifecycle | `dispose()` checks `_didSaveSuccessfully` | Widget handles draft save/clear in `dispose`; controller only clears on successful save |

## Data Flow

```
┌─────────────────────┐
│  CreateEntrySheet   │  ──reads──►  CreateEntryState (title, content, tags,
│  (ConsumerStateful) │              detectedType, manualType, effectiveType,
│                     │              isSaving, error)
│  onChanged(content) │──call──►  detectTypeFromContent(deltaJson)
│  onChanged(title)   │──call──►  state = state.copyWith(title: ...)
│  onChanged(tags)    │──call──►  state = state.copyWith(tags: ...)
│  FilledButton tap   │──call──►  save()
│                     │
│  dispose()          │──call──►  draftNotifier.save(...) / clear()
└─────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────┐
│  CreateEntryController                               │
│  - detectTypeFromContent(deltaJson)                  │
│  - processContentForType(type, body, title, tags)    │
│  - save() → createEntry(...) → clear draft → invalidate │
└─────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────┐
│  QuickAddSheet  (ConsumerStateful)                   │
│  - multi-task guard: if extractTaskLines > 0,        │
│    skip controller, call createEntry directly        │
│  - single entry: convert plain text to Delta JSON    │
│    via RichTextHelper, then call same controller     │
│  - onChanged: wrap text → Delta → detectTypeFromContent │
└─────────────────────────────────────────────────────┘
```

## QuickAddSheet Integration

QuickAddSheet maps plain text to the Delta-JSON-focused controller:

| QuickAddSheet Action | Controller Path |
|---------------------|-----------------|
| `_onTextChanged(text)` | `RichTextHelper.plainTextToDocument(text)` → `documentToJson()` → `detectTypeFromContent(deltaJson)` |
| `_save()` single-entry | Convert text to Delta JSON → call `save()` (controller handles rest) |
| Multi-task (guard) | **Skip controller entirely** — existing `extractTaskLines` block unchanged, calls `createEntry` directly |
| `_buildParsePreview()` | Read `state.effectiveType`, `state.title`, `state.tags` from controller state (or compute preview from raw text locally for responsiveness) |

The preview can be computed from raw text locally to avoid roundtripping through Delta JSON. But using `processContentForType` for preview would mean full save path runs — too heavy. **Recommendation**: keep a lightweight local preview calculation in QuickAddSheet (30 lines), or compute preview directly from state values (type + title + tags already parsed by controller).

## Widget Integration Points

### CreateEntrySheet reads from state:
- `state.effectiveType` → type icon/label in header
- `state.isManual` → header chip color
- `state.isSaving` → button disabled + spinner
- `state.error` → snackbar display (watch in build, show in listener)

### CreateEntrySheet calls:
- `RichTextEditor.onChanged` → `controller.detectTypeFromContent(deltaJson)`
- `_titleCtrl.onChanged` → `state = state.copyWith(title: newValue)`
- `_tagsCtrl.onChanged` → `state = state.copyWith(tags: newValue)`
- `PopupMenuButton.onSelected` → `controller.setManualType(type)`
- `FilledButton.onPressed` → `controller.save()`

### Draft restoration (in initState):
```dart
final draft = ref.read(entryDraftProvider);
if (draft != null) {
  controller.loadDraft(draft);
  if (draft.content.isNotEmpty) {
    controller.detectTypeFromContent(draft.content);
  }
}
```

### Draft save (in dispose):
```dart
if (!_didSaveSuccessfully && hasContent) {
  draftNotifier.save(EntryDraft(
    title: state.title,
    content: state.content,
    tags: state.tags,
    manualType: state.manualType,
  ));
}
```

Widget owns `_didSaveSuccessfully` flag — set by listener on successful save.

## Dependencies & Provider Registration

```dart
// In entry_providers.dart — add after credentialProtectionControllerProvider

final createEntryControllerProvider =
    StateNotifierProvider<CreateEntryController, CreateEntryState>((ref) {
  return CreateEntryController(
    createEntry: ref.watch(createEntryProvider),
    draftNotifier: ref.watch(entryDraftProvider.notifier),
    ref: ref,
  );
});
```

### Constructor:
```dart
CreateEntryController({
  required CreateEntry createEntry,
  required EntryDraftNotifier draftNotifier,
  required Ref ref,   // for ref.invalidate(entryListProvider) on save
})
```

### File Structure

| File | Action |
|------|--------|
| `lib/ui/controllers/create_entry_controller.dart` | **Create** — state + controller + ProcessedContent |
| `lib/ui/providers/entry_providers.dart` | **Modify** — add `createEntryControllerProvider` |
| `lib/ui/screens/create_entry_sheet.dart` | **Modify** — delegate to controller, remove ~200 lines |
| `lib/ui/screens/quick_add_sheet.dart` | **Modify** — use controller, keep multi-task guard, ~120 lines removed |
| `test/controllers/create_entry_controller_test.dart` | **Create** — unit tests |

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `CreateEntryController` constructor & initial state | Verify default state values |
| Unit | `detectTypeFromContent` — 5 entry types + empty | Mock `RichTextHelper static` indirectly via actual helper; feed Delta JSON; verify `detectedType` |
| Unit | `detectTypeFromContent` — malformed JSON | Feed `"invalid"`; verify `detectedType` stays null |
| Unit | `splitTitle` — with `# ` marker | `"Salsa# !idea"` → title:"Salsa", rest:"!idea" |
| Unit | `splitTitle` — no marker | `"no marker"` → title:"", rest:"no marker" |
| Unit | `splitTitle` — empty string | `""` → title:"", rest:"" |
| Unit | `extractTags` — delegates to RichTextHelper | Verify `-#tag` extraction + clean text |
| Unit | `stripTitleAndTags` — prefix + tags | Delta JSON with "Meeting# " prefix + `-#work`; verify stripped output |
| Unit | `processContentForType` — each entry type | Feed each type + body; verify content, metadata, secret, requiresAuth |
| Unit | `processContentForType` — credential parse failure | Feed credential text that fails parsing; verify fallback to note |
| Unit | `save()` — calls createEntry with correct params | Mock `CreateEntry`, verify call with expected args |
| Unit | `save()` — early return on empty content | Both title + content empty; verify createEntry NOT called |
| Unit | `save()` — error handling | Mock `CreateEntry` throws; verify `isSaving` = false, `error` set |
| Unit | `setManualType` / `loadDraft` / `reset` | Verify state transitions |

### Test file structure:
```
test/controllers/
├── create_entry_controller_test.dart
├── create_entry_state_test.dart     ← Freezed constraints (optional)
└── processed_content_test.dart      ← Freezed constraints (optional)
```

`extractTags` and `stripPrefix`/`stripTagsFromContent` are tested in `RichTextHelper`'s existing tests — controller tests verify delegation, not re-test the helper.

## Migration / Rollout

No migration required. Pure refactoring — behavior is identical before and after. Verify by running all existing tests + new controller tests.

## Open Questions

- [ ] Should `_buildParsePreview()` in QuickAddSheet compute from controller state or keep local computation? Proposal says widget keeps lightweight local preview. Decision: **local** — avoids Delta-roundtrip on every keystroke and keeps preview responsive.
- [ ] `QuickAddSheet` glossary path extracts `entryTitle` from `:` split (`service:definition` → title:service) — controller's `processContentForType` must handle this title extraction for glossary type. Confirm this is the intended unified behavior.
