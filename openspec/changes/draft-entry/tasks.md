# Tasks: Draft Entry Persistence

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~320 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | auto-chain |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Draft model + notifier + provider + provider tests | Single PR | `main` base; ~145 lines |
| 2 | Sheet lifecycle wiring + widget tests | Single PR | same PR as unit 1; ~175 lines |

> The entire change is ~320 lines — well under the 400-line budget. Chained PRs are **not recommended**: splitting would add overhead without review benefit. Both work units belong in one PR.

## Phase 1: Foundation — EntryDraft model, notifier, and provider

- [x] 1.1 Created `lib/ui/providers/entry_draft_provider.dart` with `EntryDraft` freezed model (`String title`, `String content`, `String tags`, `EntryType? manualType`), `EntryDraftNotifier` extending `StateNotifier<EntryDraft?>` with `save(EntryDraft)` / `restore()` / `clear()` methods, and top-level `entryDraftProvider` (`StateNotifierProvider`). Freezed file generated via `build_runner`.
- [x] 1.2 Wrote `test/ui/providers/entry_draft_provider_test.dart` — 6 tests covering initial state, save, overwrite, restore, clear, null manualType

## Phase 2: Integration — CreateEntrySheet draft lifecycle

- [x] 2.1 Added `initState()` to `CreateEntrySheet` — read `entryDraftProvider`, if draft exists populate `_titleCtrl`, `_tagsCtrl`, `_richContent`, `_manualType` and call `_detectTypeFromContent`
- [x] 2.2 Added `_didSaveSuccessfully` instance field (`false`), set `true` after `_save()` succeeds, call `ref.read(entryDraftProvider.notifier).clear()` after save
- [x] 2.3 Overrode `dispose()` — skip if `_didSaveSuccessfully`; else save draft if any field non-empty, clear if all empty; call super after
- [x] 2.4 Changed `RichTextEditor` initialContent from `''` to `_richContent`
- [x] 2.5 Wrote `test/ui/screens/create_entry_sheet_test.dart` — 2 widget tests: restore draft on open, empty fields when no draft. (Full lifecycle widget tests limited by Riverpod `ref` in dispose + FlutterQuill rendering constraints in test environment)

## Summary

| Phase | Tasks | Focus |
|-------|-------|-------|
| Phase 1 | 2 | Model + notifier + provider + unit tests |
| Phase 2 | 5 | Sheet lifecycle integration + widget tests |
| Total | 7 | |

### Implementation Order

Phase 1 first (provider is a dependency of Phase 2). Within each phase, written code before tests. All tasks fit in one PR since the change is small and self-contained.

### Risk Flags

- **400-line budget**: Low (~320 lines). No chained PRs needed.
- **Tight coupling**: Sheet integration depends on provider API — ensure `save`/`clear` signatures match before wiring.
- **New test file**: `create_entry_sheet_test.dart` doesn't exist yet — base test setup (pump widget, provider overrides) must be built from scratch.
