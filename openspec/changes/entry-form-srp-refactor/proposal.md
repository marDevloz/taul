# Proposal: EntryFormSheet SRP Refactoring

## Intent

`EntryFormSheet` (901 lines, 6 responsibilities) mixes create mode, edit mode, draft persistence, tag autocomplete, type selector, and quick commands help into a single widget. Extract 4 focused widgets + thin orchestrator to make each responsibility independently testable and maintainable.

## Scope

### In Scope
- `EntryFormCreateSheet` — create mode: draft init/dispose, controller binding, type detection
- `EntryFormEditSheet` — edit mode: rich content state, save with tag extraction, invalidation
- `TagAutocompleteField` — tags text field + unified suggestion chip
- `EntryTypeSelector` — unified type popup button (replaces duplicated `_buildTypeSelectorButton` vs `_buildTypeSelector`)
- `QuickCommandsSheet` — help bottom sheet (extracted private `_showQuickCommands`)
- Thin `EntryFormSheet` orchestrator — layout, header, button bar, credential routing (~80 lines)
- Zone new widgets under `lib/ui/widgets/entry_form/`
- Update 3 callers for new import paths

### Out of Scope
- Behavioral changes (zero functional change)
- Draft lifecycle refactoring (stays in create-mode widget)
- `CreateEntryController` changes (untouched)
- Type detection algorithm or entry type model changes
- Rich text editor changes

## Capabilities

None — pure internal refactoring, no spec-level behavior change. Specs `entry-draft`, `system-tags`, `task-type` are unaffected.

## Approach

**Layer**: UI only (widget layer decompose).

Editor `GlobalKey` stays in orchestrator — both modes need it. Child widgets receive `editorHashTagPartial` via constructor and notify via callback. Draft lifecycle moves to `EntryFormCreateSheet` (initState restore, dispose save/clear with `Future.microtask`). Credential routing stays in orchestrator (type selector calls callback on credential selection). Button bar shared across modes via conditional callbacks.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/ui/widgets/entry_form_sheet.dart` | **Modified** | Thin orchestrator, ~80 lines |
| `lib/ui/widgets/entry_form/entry_form_create_sheet.dart` | **New** | Create mode (~150 lines from extracted) |
| `lib/ui/widgets/entry_form/entry_form_edit_sheet.dart` | **New** | Edit mode (~120 lines from extracted) |
| `lib/ui/widgets/entry_form/tag_autocomplete_field.dart` | **New** | Tags + suggestion (~120 lines) |
| `lib/ui/widgets/entry_form/entry_type_selector.dart` | **New** | Unified type selector (~120 lines) |
| `lib/ui/widgets/entry_form/quick_commands_sheet.dart` | **New** | Help bottom sheet (~70 lines) |
| `lib/ui/screens/create_entry_sheet.dart` | **Modified** | Import path |
| `lib/ui/screens/entry_detail_view.dart` | **Modified** | Import path |
| `lib/ui/screens/home_view.dart` | **Modified** | Import path |
| `test/widgets/entry_form/` | **New** | Widget tests for extracted components |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Editor `GlobalKey` shared across widgets breaks | Low | Key stays in orchestrator, passed as prop to children |
| Draft dispose race condition (`Future.microtask`) | Low | Preserve exact timing pattern in `EntryFormCreateSheet.dispose` |
| Tag autocomplete cross-widget flow breaks | Low | Orchestrator bridges `_editorHashTagPartial` updates to `TagAutocompleteField` |
| Credential routing mis-wired | Low | `EntryTypeSelector` exposes `onCredentialSelected` callback, orchestrator handles routing |

## Rollback Plan

Revert `entry_form_sheet.dart`, `create_entry_sheet.dart`, `entry_detail_view.dart`, `home_view.dart` to HEAD. Delete `lib/ui/widgets/entry_form/` directory. No migration or data loss — pure structural change.

## Dependencies

None — internal refactoring only. All dependencies (`CreateEntryController`, `EntryDraftNotifier`, `RichTextHelper`) are unchanged.

## Success Criteria

- [ ] Create mode: draft restore, type detection, save — identical behavior vs HEAD
- [ ] Edit mode: load, content/tag save with invalidation — identical behavior vs HEAD
- [ ] Tag autocomplete works from both editor `-#` and tags field
- [ ] Type selector unified (no duplicated `_buildTypeSelector` methods)
- [ ] Quick commands help opens with same content
- [ ] All 3 callers compile with updated imports
- [ ] `dart analyze` passes with zero warnings
- [ ] No behavioral regressions in credential routing
