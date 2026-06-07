# Tasks: CreateEntryController

Extract shared parsing, type-detection, content-formatting, and save-orchestration logic from `CreateEntrySheet` and `QuickAddSheet` into a `StateNotifier<CreateEntryState>` backed by a Riverpod `StateNotifierProvider`. Both sheets become thin UI shells.

## Phase 1: Controller + State Models (New file)

### T1.1 Create Freezed state models

| Field | Value |
|---|---|
| **ID** | `T1.1` |
| **File** | `lib/ui/controllers/create_entry_controller.dart` |
| **Description** | Create `CreateEntryState` and `ProcessedContent` Freezed classes with all fields, computed getters, and proper defaults. |
| **Dependencies** | None |
| **Effort** | Small (30 min) |

**Acceptance Criteria:**
- `CreateEntryState` has fields: `title` (String), `content` (String, Delta JSON), `tags` (String, comma-separated), `detectedType` (EntryType?), `manualType` (EntryType?), `isSaving` (bool, default `false`), `error` (String?)
- Computed getter `effectiveType` returns `manualType ?? detectedType ?? EntryType.note`
- Computed getter `isManual` returns `manualType != null`
- `ProcessedContent` has fields: `content` (String), `metadata` (Map<String, String>), `secret` (String?), `requiresAuth` (bool, default `false`), `tags` (List<String>, default `[]`)
- Both classes use `@freezed` with proper `part` directives
- `dart analyze` passes on the new file (defer build errors until T1.2 is complete)

### T1.2 Implement CreateEntryController — static/stateless helpers

| Field | Value |
|---|---|
| **ID** | `T1.2a` |
| **File** | `lib/ui/controllers/create_entry_controller.dart` |
| **Description** | Implement the pure static methods: `splitTitle`, `extractTags`, `stripTitleAndTags`. |
| **Dependencies** | T1.1 |
| **Effort** | Small (30 min) |

**Acceptance Criteria:**
- `splitTitle(String plainText)` → `({String title, String rest})`:
  - `"Salsa# !idea"` → `(title: "Salsa", rest: "!idea")`
  - `"no marker"` → `(title: "", rest: "no marker")`
  - `""` → `(title: "", rest: "")`
  - Logic ported identically from `CreateEntrySheet._splitTitle` (iterate chars, find `# ` boundary)
- `extractTags(String raw)` → `({String clean, List<String> tags})`:
  - Delegates to `RichTextHelper.extractTags(raw)` — pure pass-through
- `stripTitleAndTags(String deltaJson, List<String> tags, String titlePrefix)` → `String`:
  - Logic ported from `CreateEntrySheet._stripTitleAndTags`
  - Order: strip `"$titlePrefix# "` prefix FIRST via `RichTextHelper.stripPrefix`, THEN strip `-#tag` markers via `RichTextHelper.stripTagsFromContent`
  - Parameterized: takes explicit `deltaJson` instead of reading local state

### T1.3 Implement CreateEntryController — detectTypeFromContent + processContentForType

| Field | Value |
|---|---|
| **ID** | `T1.3` |
| **File** | `lib/ui/controllers/create_entry_controller.dart` |
| **Description** | Implement `detectTypeFromContent` (type detection from Delta JSON) and `processContentForType` (content formatting per entry type). |
| **Dependencies** | T1.1, T1.2a |
| **Effort** | Medium (1h) |

**Acceptance Criteria:**
- `detectTypeFromContent(String deltaJson)`:
  - Ports logic from `CreateEntrySheet._detectTypeFromContent` (the more correct version over QuickAddSheet's)
  - Converts Delta JSON → plain text via `RichTextHelper`
  - Checks `!` (idea) **BEFORE** `Title#` split
  - Splits `Title#`, then checks task marker, credential regex `\w+\*\w+\*\w+`, glossary regex `\w{2,}:(?!//)\s*\S`
  - Sets `state.detectedType` to `null` if content is empty or malformed
  - Catches JSON parse errors silently (detectedType stays null)
- `processContentForType(EntryType type, String body, String title, List<String> tags)` → `ProcessedContent`:
  - **idea**: strip leading `!` from body
  - **glossary**: call `RichTextHelper.formatForGlossary(body)` — does NOT extract/invent title from `:` split (leave title empty if no manual title provided)
  - **credential**: `CredentialParser.parse(body)`, build metadata/secret/requiresAuth; on parse failure, fall back to note with `stripTitleAndTags`
  - **task**: `stripTitleAndTags` + strip task marker via `RichTextHelper.stripPrefix`
  - **note**: `stripTitleAndTags`
  - Pure function — does NOT mutate state (side-effect-free transformation)

### T1.4 Implement CreateEntryController — save orchestration + lifecycle

| Field | Value |
|---|---|
| **ID** | `T1.4` |
| **File** | `lib/ui/controllers/create_entry_controller.dart` |
| **Description** | Implement `save()` (full save orchestration), `reset()`, `loadDraft()`, `setManualType()`. Wire constructor with explicit deps. |
| **Dependencies** | T1.1, T1.2a, T1.3 |
| **Effort** | Medium (1h) |

**Acceptance Criteria:**
- Constructor signature:
  ```dart
  CreateEntryController({
    required CreateEntry createEntry,
    required EntryDraftNotifier draftNotifier,
    required Ref ref,
  });
  ```
- `reset()`: resets all fields to defaults (title: `""`, content: `""`, tags: `""`, detectedType: `null`, manualType: `null`, isSaving: `false`, error: `null`)
- `loadDraft(EntryDraft draft)`: sets title, content, tags, manualType from draft
- `setManualType(EntryType? type)`: sets `state.manualType`
- `save()` orchestration (does NOT mutate state except `isSaving`/`error`):
  1. Early return if both `state.content` and `state.title` are empty (`createEntry` NOT called)
  2. Convert Delta JSON → plain text via `RichTextHelper`
  3. `extractTags(plainText)` → tags + clean text
  4. `splitTitle(clean)` → title + body
  5. Merge manual tags (from `state.tags` split by `,`) + extracted tags (no duplicates)
  6. Final title: `state.title.isNotEmpty ? state.title : parsedTitle`
  7. Call `processContentForType(effectiveType, body, finalTitle, finalTags)`
  8. Set `state.isSaving = true`
  9. Call `createEntry(...)` with all params
  10. On success: clear draft via `draftNotifier.clear()`, `ref.invalidate(entryListProvider)`, set `state.isSaving = false`
  11. On error: set `state.isSaving = false`, set `state.error = error message`
- Success/failure state mutations happen BEFORE the widget reads them (no race conditions)

## Phase 2: Provider Registration

### T2.1 Register createEntryControllerProvider

| Field | Value |
|---|---|
| **ID** | `T2.1` |
| **File** | `lib/ui/providers/entry_providers.dart` |
| **Description** | Add `createEntryControllerProvider` as a `StateNotifierProvider` after `credentialProtectionControllerProvider`. |
| **Dependencies** | T1.4 (controller exists) |
| **Effort** | Trivial (10 min) |

**Acceptance Criteria:**
- Provider registered with correct imports (`create_entry_controller.dart`)
- Provider creates `CreateEntryController` with `ref.watch(createEntryProvider)`, `ref.watch(entryDraftProvider.notifier)`, and `ref`
- Import for `CreateEntryController` added at top of file
- `dart analyze` passes with zero warnings

## Phase 3: CreateEntrySheet Refactor

### T3.1 Refactor CreateEntrySheet to delegate to controller

| Field | Value |
|---|---|
| **ID** | `T3.1` |
| **File** | `lib/ui/screens/create_entry_sheet.dart` |
| **Description** | Replace all parsing, type-detection, save logic in `CreateEntrySheet` with controller delegation. Remove duplicated logic (~200 lines). |
| **Dependencies** | T2.1 (provider available) |
| **Effort** | Medium (1.5h) |
| **Risk** | High — must preserve exact UI behavior |

**Acceptance Criteria:**
- Widget changes from `ConsumerStatefulWidget` to watch `createEntryControllerProvider`
- **Removed**: `_richContent`, `_detectedType`, `_manualType`, `_isSaving`, `_effectiveType` getter, `_isManual` getter — all now on controller state
- **Removed**: `_splitTitle`, `_extractTags`, `_stripTitleAndTags`, `_detectTypeFromContent`, `_setType`, `_save` methods
- **Kept**: `_titleCtrl`, `_tagsCtrl` (TextEditingControllers — widget owns them)
- **Kept**: `_didSaveSuccessfully` flag for dispose logic
- **Kept**: `_iconForType`, `_labelForType` UI helpers
- **Kept**: `initState` draft restoration — reads from `entryDraftProvider`, calls `controller.loadDraft()` + `detectTypeFromContent()`
- **Kept**: `dispose` with draft save/clear logic (same try/catch pattern)
- **Build method reads from controller state**:
  - `state.effectiveType` → type icon/label in header
  - `state.isManual` → header chip color (primaryContainer vs surfaceContainerHighest)
  - `state.isSaving` → button disabled + spinner
  - `state.error` → display snackbar via `ref.listen` (watch for non-null error)
- **Event wiring**:
  - `RichTextEditor.onChanged` → `controller.detectTypeFromContent(deltaJson)`
  - `_titleCtrl.onChanged` → `controller.state = state.copyWith(title: newValue)`
  - `_tagsCtrl.onChanged` → `controller.state = state.copyWith(tags: newValue)`
  - `PopupMenuButton.onSelected` → `controller.setManualType(type)`
  - `FilledButton.onPressed` → `controller.save()`
- **Save success listener**: widget sets `_didSaveSuccessfully = true` and pops on successful save. Controller's `save()` does NOT pop — widget listens to state changes or uses a callback. **Decision**: controller returns Future from `save()`, widget awaits and pops on success.
- `dart analyze` passes with zero warnings
- All existing `CreateEntrySheet` widget tests pass with provider overrides (T5.3)

### T3.2 Remove credential_protection_controller import if unused

| Field | Value |
|---|---|
| **ID** | `T3.2` |
| **File** | `lib/ui/providers/entry_providers.dart` / potentially `create_entry_sheet.dart` |
| **Description** | After refactor, verify no unused imports remain from moved logic. |
| **Dependencies** | T3.1 |
| **Effort** | Trivial (5 min) |

**Acceptance Criteria:**
- No unused imports in `create_entry_sheet.dart`
- No unused imports in `entry_providers.dart`
- `dart analyze` passes

## Phase 4: QuickAddSheet Refactor

### T4.1 Refactor QuickAddSheet single-entry path to use controller

| Field | Value |
|---|---|
| **ID** | `T4.1` |
| **File** | `lib/ui/screens/quick_add_sheet.dart` |
| **Description** | Replace single-entry parsing/save logic with controller delegation. Keep multi-task guard untouched. Remove ~120 lines. |
| **Dependencies** | T2.1 (provider available) |
| **Effort** | Medium (1.5h) |
| **Risk** | High — multi-task guard must stay intact, plain-text → Delta conversion must work |

**Acceptance Criteria:**
- **Kept intact**: Multi-task flow (extractTaskLines > 0) — SKIPS controller entirely, calls `createEntry` directly as before
- **Kept**: `_controller` (TextEditingController), `_iconForType`, `_labelForType`, `_buildParsePreview`
- **Kept**: `_typeHints`, `_selectHint`, hint chips, build layout
- **Kept**: `_effectiveType` and `_isManual` getters — read from state or replace with controller state reads
- **Removed**: `_detectedType`, `_manualType`, `_isSaving` local fields — now from controller state
- **Removed**: `_splitTitle`, `_extractTags` methods — use controller statics or delegate
- **Removed**: `_onTextChanged` inline detection — replaced with plain-text-to-Delta conversion + `controller.detectTypeFromContent(deltaJson)`
- **Modified**: single-entry `_save()` path:
  - Convert `_controller.text` to Delta JSON via `RichTextHelper.plainTextToDocument()` + `documentToJson()`
  - Set content on controller: update state and call `controller.save()`
  - On success, pop (no manual `createEntry` call)
- **Modified**: `_onTextChanged`:
  - Convert text → Delta JSON → call `controller.detectTypeFromContent(deltaJson)`
- **Preview**: `_buildParsePreview` reads from controller state (`state.effectiveType`, `state.title`, `state.tags`) or keeps local lightweight calculation from raw text. **Decision**: keep local computation from raw text for responsiveness (avoids Delta-roundtrip on every keystroke)
- **Error handling**: same as CreateEntrySheet — listen for `state.error`, show snackbar
- `dart analyze` passes with zero warnings

### T4.2 Remove unused imports from QuickAddSheet

| Field | Value |
|---|---|
| **ID** | `T4.2` |
| **File** | `lib/ui/screens/quick_add_sheet.dart` |
| **Description** | Clean up imports no longer needed after refactor. |
| **Dependencies** | T4.1 |
| **Effort** | Trivial (5 min) |

**Acceptance Criteria:**
- Only `credential_parser.dart` import kept if still used in `_buildParsePreview` credential branch — otherwise removed
- `dart analyze` passes

## Phase 5: Tests

### T5.1 Unit tests — CreateEntryState Freezed constraints (optional)

| Field | Value |
|---|---|
| **ID** | `T5.1` |
| **File** | `test/controllers/create_entry_state_test.dart` |
| **Description** | Verify Freezed-generated methods: `==`, `hashCode`, `copyWith`, `toString`. |
| **Dependencies** | T1.1 |
| **Effort** | Small (20 min) |
| **Optional** | Yes — low value, skip if time-constrained |

**Acceptance Criteria:**
- Default state values match expectations
- `copyWith` correctly overwrites individual fields
- `effectiveType` returns `manualType` when set, `detectedType` when only that is set, `EntryType.note` when both null
- `isManual` reflects `manualType != null`

### T5.2 Unit tests — ProcessedContent Freezed constraints (optional)

| Field | Value |
|---|---|
| **ID** | `T5.2` |
| **File** | `test/controllers/processed_content_test.dart` |
| **Description** | Verify Freezed-generated methods for `ProcessedContent`. |
| **Dependencies** | T1.1 |
| **Effort** | Small (10 min) |
| **Optional** | Yes |

### T5.3 Unit tests — CreateEntryController

| Field | Value |
|---|---|
| **ID** | `T5.3` |
| **File** | `test/controllers/create_entry_controller_test.dart` |
| **Description** | Comprehensive unit tests for controller state management, parsing methods, type detection, content formatting, and save orchestration. |
| **Dependencies** | T1.4 (controller exists), T2.1 (provider available for integration tests) |
| **Effort** | Large (2h) |
| **Risk** | Medium — save() orchestrates multiple dependencies that need mocking |

**Acceptance Criteria — test scenarios:**

| # | Scenario | Expectation |
|---|----------|-------------|
| 1 | Constructor initial state | Default values: title `""`, content `""`, tags `""`, detectedType `null`, manualType `null`, isSaving `false`, error `null` |
| 2 | `detectTypeFromContent` — idea | Feed Delta JSON for `"!idea"` → detectedType = `EntryType.idea` |
| 3 | `detectTypeFromContent` — task | Feed Delta JSON for `"[] do this"` → detectedType = `EntryType.task` |
| 4 | `detectTypeFromContent` — credential | Feed Delta JSON for `"serv*user*pass"` → detectedType = `EntryType.credential` |
| 5 | `detectTypeFromContent` — glossary | Feed Delta JSON for `"term:definition"` → detectedType = `EntryType.glossary` |
| 6 | `detectTypeFromContent` — note | Feed Delta JSON for plain text → detectedType = `EntryType.note` |
| 7 | `detectTypeFromContent` — empty | Empty string → detectedType stays null |
| 8 | `detectTypeFromContent` — malformed JSON | `"invalid"` → caught silently, detectedType stays null |
| 9 | `detectTypeFromContent` — idea BEFORE Title# split | `"Salsa# !idea"` → detectedType = `idea` (not `note`) |
| 10 | `splitTitle` — with `# ` marker | `"Salsa# !idea"` → `(title: "Salsa", rest: "!idea")` |
| 11 | `splitTitle` — no marker | `"no marker"` → `(title: "", rest: "no marker")` |
| 12 | `splitTitle` — empty string | `""` → `(title: "", rest: "")` |
| 13 | `extractTags` — delegates correctly | Calls `RichTextHelper.extractTags` and returns result |
| 14 | `stripTitleAndTags` — prefix + tags | Delta JSON with `"Meeting# "` prefix + `-#work`; verify stripped output |
| 15 | `processContentForType` — idea | Body `"!idea"` → content `"idea"` |
| 16 | `processContentForType` — glossary | Calls `formatForGlossary`, returns formatted Delta JSON |
| 17 | `processContentForType` — credential | `"serv*user*pass"` → correct metadata/secret/requiresAuth=true |
| 18 | `processContentForType` — credential parse fail | Invalid credential → falls back to note, stripped content |
| 19 | `processContentForType` — task | Body with `[] ` marker → stripped content |
| 20 | `processContentForType` — note | Body → `stripTitleAndTags` applied |
| 21 | `save()` — calls createEntry with correct params | Mock `CreateEntry`, verify call with `title`, `content`, `type`, `secret`, etc. |
| 22 | `save()` — early return on empty content | Both title + content empty → `createEntry` NOT called |
| 23 | `save()` — error handling | Mock `CreateEntry` throws → `isSaving` = `false`, `error` set |
| 24 | `setManualType` | Set type → verify `manualType` and `isManual` |
| 25 | `loadDraft` | Load draft → verify all fields populated |
| 26 | `reset` | After mutations → verify all fields back to defaults |
| 27 | `save()` — manual title overrides parsed title | Manual title set → `createEntry` called with manual title, not parsed one |
| 28 | `save()` — tags merged (manual + extracted) | Manual tags `"work, personal"` + extracted `-#urgent` → all 3 tags sent to `createEntry` |
| 29 | `save()` — credential with no parsed title | No manual title, no `Title#` in content → `createEntry` called with empty `title` (glossary stays empty too per clarification) |

**Testing approach:**
- Mock `CreateEntry` (use `mocktail`)
- Use real `EntryDraftNotifier` (it's a simple in-memory notifier)
- Optionally pass `Ref` mock or test controller methods in isolation (static methods don't need ref)
- `save()` needs Ref mock for `ref.invalidate` — verify it's called
- Use real `RichTextHelper` for extraction/detection (no need to mock it — pure static methods)
- Use real `CredentialParser` for credential formatting

### T5.4 Verify existing widget tests still pass

| Field | Value |
|---|---|
| **ID** | `T5.4` |
| **File** | `test/ui/screens/create_entry_sheet_test.dart` |
| **Description** | Run all existing widget tests after CreateEntrySheet refactor. Update provider overrides if needed. |
| **Dependencies** | T3.1 (sheet refactored) |
| **Effort** | Small (30 min) |

**Acceptance Criteria:**
- Existing `CreateEntrySheet` draft restoration tests pass
- Override `createEntryControllerProvider` with a test controller in the test's `ProviderContainer`
- No regressions
- `flutter test` passes on all existing tests

### T5.5 Final analysis check

| Field | Value |
|---|---|
| **ID** | `T5.5` |
| **File** | (whole project) |
| **Description** | Run full `dart analyze` to ensure zero warnings. |
| **Dependencies** | T3.1, T4.1 |
| **Effort** | Trivial (5 min) |

**Acceptance Criteria:**
- `dart analyze` passes with zero warnings across the entire project
- No unused imports, no unused locals, no type errors

## Phase 6: Cleanup & Verification

### T6.1 Run all tests and verify behavior

| Field | Value |
|---|---|
| **ID** | `T6.1` |
| **Description** | Run full test suite, verify both sheets open/parse/save correctly. |
| **Dependencies** | All previous tasks |
| **Effort** | Small (20 min) |

**Acceptance Criteria:**
- `flutter test` passes on all tests (existing + new controller tests)
- Manual verification (or automated if possible):
  - `CreateEntrySheet` opens, parses content, detects type, saves — identical behavior
  - `QuickAddSheet` opens, parses plain text, detects type, saves — identical behavior
  - Multi-task flow in QuickAddSheet creates multiple task entries (skips controller)
  - Draft restoration works in CreateEntrySheet

## Rollback Plan

| Step | Action | Command |
|------|--------|---------|
| R1 | Revert sheet files | `git checkout HEAD -- lib/ui/screens/create_entry_sheet.dart lib/ui/screens/quick_add_sheet.dart` |
| R2 | Delete controller file | `git rm lib/ui/controllers/create_entry_controller.dart` |
| R3 | Revert provider file | `git checkout HEAD -- lib/ui/providers/entry_providers.dart` |
| R4 | Delete test files | `git rm -r test/controllers/` |
| R5 | Verify clean state | `git status` — only expected files changed |
| R6 | Cleanup | `git clean -fd` removes any leftover generated `.freezed.dart` files if the controller was created but not committed |

**No migration or data loss**: this is a pure internal refactoring with no schema changes or data migration.

## Dependency Graph

```
T1.1 ──► T1.2a ──► T1.3 ──► T1.4 ──► T2.1 ──┬──► T3.1 ──┬──► T3.2 ──┐
                                               │            │            │
                                               │            └────────────┴──► T5.4 ──┐
                                               │                                  │
                                               └──► T4.1 ──► T4.2 ───────────────┴──► T5.5 ──► T6.1
                                                                                         ▲
T1.4 ───────────────────────────────────────────────────────────────────────────────────┘
  │
  └──► T5.1 (optional)
  └──► T5.2 (optional)
  └──► T5.3
```

**Task summary by effort:**
- Trivial (≤10 min): T2.1, T3.2, T4.2, T5.5
- Small (≤30 min): T1.1, T1.2a, T5.1, T5.2, T5.4, T6.1
- Medium (≤1.5h): T1.3, T1.4, T3.1, T4.1
- Large (≤2h): T5.3

**Total estimated effort**: ~8.5 hours (excluding optional tasks: ~9h with T5.1 + T5.2)
