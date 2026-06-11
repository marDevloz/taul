# Tasks: EntryFormSheet SRP Refactoring

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1,400 additions + deletions |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1: Leaf widgets → PR 2: Create+Edit → PR 3: Orchestrator |
| Delivery strategy | ask-on-risk |
| Chain strategy | pending |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Base branch | Lines |
|------|------|-----------|-------------|-------|
| 1 | Leaf widgets (QuickCommandsSheet, EntryTypeSelector, TagAutocompleteField) | PR 1 | tracker | ~280 new |
| 2 | Create + Edit mode widgets (EntryFormCreateSheet, EntryFormEditSheet) | PR 2 | PR 1 branch | ~250 new |
| 3 | Orchestrator rewrite + callers | PR 3 | PR 2 branch | ~80 new + ~821 old |

## Phase 1: Leaf Widgets (zero dependencies)

- [ ] 1.1 Create `lib/ui/widgets/entry_form/` directory
- [ ] 1.2 `quick_commands_sheet.dart` — static `show()` + public `QuickCommandTile` (ex `_CommandEntry`)
- [ ] 1.3 `entry_type_selector.dart` — stateless `PopupMenuButton<EntryType?>`, `_iconForType`/`_labelForType` helpers, `showAutoOption` flag
- [ ] 1.4 `tag_autocomplete_field.dart` — `ConsumerStatefulWidget` with `_unifiedSuggestion` bridge, suggestion chip, `onAcceptSuggestion` callback
- [ ] 1.5 Test: `TagAutocompleteField` — editor suggestion renders, accept invokes callback
- [ ] 1.6 Test: `EntryTypeSelector` — 5 types listed, credential fires `onSelected`
- [ ] 1.7 Test: `QuickCommandsSheet` — 6 command entries render

## Phase 2: Create + Edit Mode Widgets

- [ ] 2.1 `entry_form_create_sheet.dart` — `initState`: draft restore + controller binding; `dispose`: auto-save/clear; `_saveCreate`; build: title, editor (GlobalKey prop), type hints, buttons
- [ ] 2.2 `entry_form_edit_sheet.dart` — `_selectedType`/`_isSaving`/`_richContent`; `_saveEdit`: tag merge, content strip, `invalidate` providers; build: title, type selector, editor, buttons
- [ ] 2.3 Test: `EntryFormCreateSheet` — draft restore on init, auto-save on dismiss, cancel clears draft
- [ ] 2.4 Test: `EntryFormEditSheet` — load entry fixture, save merges tags, invalidation fires

## Phase 3: Orchestrator Rewrite

- [ ] 3.1 Rewrite `entry_form_sheet.dart` — ~80 lines: imports, `_editorKey`, `_titleCtrl`/`_tagsCtrl`, `_editorHashTagPartial` bridge, credential routing, layout delegating to create/edit child
- [ ] 3.2 Update `create_entry_sheet.dart` import (no API change needed — orchestrator stays at same path)
- [ ] 3.3 Run `dart analyze` — zero warnings
- [ ] 3.4 Verify existing tests pass unchanged

## Why Chain Strategy Is Pending

PR 3's git diff shows ~900 changed lines (80 additions + 821 deletions in `entry_form_sheet.dart`). The deletions are extracted code already reviewed in PR 1-2, but git counts them. Three options:

1. **Feature Branch Chain** — each PR targets previous PR branch. Reviewers see focused diffs per PR. Tracker merges to main at end. Cleanest rollback.
2. **Stacked PRs to main** — PR 1→main, PR 2→main, PR 3→main. Simplest merge flow, but PR 3's wide delete-diff hits main twice.
3. **size:exception** — single PR with maintainer approval for this pure refactoring. Safest for atomic consistency.

Which strategy do you prefer?
