# Proposal: Create Entry Controller

## Intent

`CreateEntrySheet` (427 lines) mixes parsing, type detection, content stripping, and save orchestration with UI code. `QuickAddSheet` duplicates nearly identical logic (plain text vs Delta JSON). Extract the shared orchestration into a `CreateEntryController` so both sheets become pure UI shells and the business logic is testable in isolation.

## Scope

### In Scope
- `CreateEntryController` (StateNotifier): type detection, `_splitTitle`, tag extraction, `_stripTitleAndTags`, content formatting per type, save orchestration via `createEntryProvider`
- `CreateEntryNotifier` state: form fields (title, content, tags), detected/manual type, saving state
- Refactor `CreateEntrySheet` to delegate all parsing/save to the controller
- Refactor `QuickAddSheet` to use same controller (it works on plain text, the controller handles Delta JSON transparently)
- Provider registration in `entry_providers.dart`
- Unit tests for controller logic

### Out of Scope
- Draft persistence lifecycle (already handled by `EntryDraftNotifier` — independent)
- UI changes in either sheet (buttons, layout, styling stay as-is)
- New entry types or type-detection algorithms
- Credential auth resolution (stays in `CredentialProtectionController`)

## Capabilities

### New Capabilities
None — pure internal refactoring, no new spec-level behavior.

### Modified Capabilities
None — existing `entry-draft` spec is unaffected; draft lifecycle is orthogonal to this change.

## Approach

**Pattern**: `StateNotifier<CreateEntryState>` + Riverpod `StateNotifierProvider`, same pattern as `EntryDraftNotifier` / `CredentialProtectionController`.

1. **State model** — Freezed class holding all form fields and UI state that the controller manages:
   - `title`, `content` (Delta JSON string), `tags` (comma-separated string)
   - `detectedType`, `manualType`, `effectiveType`, `isManual`
   - `isSaving`, `error`

2. **Controller** — Moves these private methods from both sheets into the controller:
   - `_splitTitle()` — same logic, operates on plain text
   - `_extractTags()` — delegates to `RichTextHelper.extractTags`
   - `_stripTitleAndTags()` — sequence of prefix + tag stripping on Delta JSON
   - `_detectTypeFromContent()` — auto-detection from Delta JSON
   - `_save()` — full orchestration: extract tags, extract title, format per type, call `createEntryProvider`

3. **Widget integration**:
   - `CreateEntrySheet.watch` → reads state from controller
   - `CreateEntrySheet.onChanged` → calls controller methods
   - `QuickAddSheet` converts plain text to Delta JSON before delegating to same controller
   - Both widgets own their `TextEditingController` instances but feed data into the controller

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/ui/providers/entry_providers.dart` | **Modified** | Add `createEntryControllerProvider` |
| `lib/ui/controllers/create_entry_controller.dart` | **New** | Controller + state model |
| `lib/ui/screens/create_entry_sheet.dart` | **Modified** | Delegate to controller, remove duplicated logic (~200 lines removed) |
| `lib/ui/screens/quick_add_sheet.dart` | **Modified** | Use same controller (~120 lines removed) |
| `test/controllers/create_entry_controller_test.dart` | **New** | Unit tests for parsing, type detection, save orchestration |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Type-detection mismatch between old inline and new controller | Low | Port logic method-by-method, verify against existing test scenarios |
| `QuickAddSheet` multi-task flow breaks | Low | The multi-task path skips the controller — guard it, don't refactor |
| `_stripTitleAndTags` ordering breaks content | Low | Sequence is order-dependent (strip prefix first, then tags) — critical test case |

## Rollback Plan

Revert `create_entry_sheet.dart` and `quick_add_sheet.dart` to HEAD, delete `lib/ui/controllers/create_entry_controller.dart`, and remove the added provider from `entry_providers.dart`. No migration or data loss.

## Dependencies

- `RichTextHelper` (core) — existing, unchanged
- `CredentialParser` (core) — existing, unchanged
- `CreateEntry` use case via `createEntryProvider` — existing, unchanged
- `EntryDraftNotifier` via `entryDraftProvider` — existing, unchanged

## Success Criteria

- [ ] `CreateEntrySheet` opens, parses content, detects type, formats body, saves — identical behavior
- [ ] `QuickAddSheet` opens, parses content, detects type, formats body, saves — identical behavior
- [ ] Multi-task flow in QuickAddSheet unchanged (skips controller)
- [ ] All parsing methods unit-tested (splitTitle, extractTags, stripTitleAndTags, detectType)
- [ ] `dart analyze` passes with zero warnings
