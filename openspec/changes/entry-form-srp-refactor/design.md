# Design: EntryFormSheet SRP Refactoring

## Technical Approach

Decompose the 901-line `EntryFormSheet` into 5 focused widgets under `lib/ui/widgets/entry_form/`, leaving a thin orchestrator (~80 lines) that holds shared controllers, GlobalKey, credential routing, and delegates to create/edit child widgets. Zero behavioral change.

## Architecture Decisions

| Decision | Option | Chosen | Rationale |
|----------|--------|--------|-----------|
| Editor `GlobalKey` owner | Orchestrator vs. each child | **Orchestrator** | Both modes need it. Passing it as prop avoids duplicating the key or losing editor state across rebuilds |
| Draft lifecycle owner | Orchestrator vs. `EntryFormCreateSheet` | **`EntryFormCreateSheet`** | Create-only concern. Keeps orchestrator clean of draft save/restore logic |
| Tag autocomplete | Self-contained vs. bridged | **Bridged via `_editorHashTagPartial`** | Editor state lives in orchestrator (GlobalKey). Child receives partial string + accept callback — no GlobalKey leak |
| Type selector state | Shared state vs. RenderObject | **Stateless + `ValueChanged<EntryType?>`** | Both modes set type differently (setState vs controller.setManualType). Stateless selector leaves mode-specific logic in the mode widget |
| `_buildTypeSelector` vs. `_buildTypeSelectorButton` | Unify | **Single `EntryTypeSelector`** | Both render the same popup with different props. The only difference: edit mode lacks "Auto" option |

### Key divergence from proposal
The proposal lists `home_view.dart` as a caller that needs import path changes. In practice, `EntryFormSheet` stays at the same file path — no caller changes required.

## Data Flow

```
                   ┌─────────────────────────────────────┐
                   │          EntryFormSheet              │
                   │    _editorKey, _titleCtrl, _tagsCtrl │
                   │    _editorHashTagPartial (bridge)    │
                   └──┬──────────────┬────────────────────┘
                      │              │
          ┌───────────┘              └────────────┐
          ▼                                       ▼
┌─────────────────────┐              ┌──────────────────────┐
│ EntryFormCreateSheet│              │  EntryFormEditSheet  │
│ - draft lifecycle   │              │  - _selectedType     │
│ - createController  │              │  - _isSaving         │
│ - type detection    │              │  - save+merge+inval  │
│ - type hints        │              └────────┬─────────────┘
└────────┬────────────┘                       │
         │        ┌───────────────────────────┘
         │        │
         ▼        ▼
┌────────────────────────────────────┐
│        TagAutocompleteField        │
│ - reads editorHashTagPartial prop │
│ - computes unified suggestion      │
│ - _tagsFieldPartial (local)       │
└─────────────┬──────────────────────┘
              │ suggestion accepted
              ▼
      orchestrator._acceptSuggestion
      → editorKey.currentState.acceptTagSuggestion()
      OR → tagsCtrl text edit
```

**Credential routing** (orchestrator-only):
```
EntryTypeSelector.onSelected(credential)
  → orchestrator._onTypeSelected(credential)
  → Navigator.pop() + CredentialFormSheet or onCredentialRequested()
```

**Tag autocomplete bridge**:
```
Editor onChanged → orchestrator._onContentChanged
  → _updateEditorHashTag() → _editorKey.currentState!.extractCurrentHashTag()
  → setState → TagAutocompleteField receives new editorHashTagPartial
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/ui/widgets/entry_form_sheet.dart` | **Modify** | Thin orchestrator (~80 lines): shared controllers, GlobalKey, `_editorHashTagPartial` bridge, credential routing, layout that delegates to create/edit widgets |
| `lib/ui/widgets/entry_form/entry_form_create_sheet.dart` | **Create** | Create mode: draft restore in `initState`, auto-save/clear in `dispose`, `CreateEntryController` binding, type detection hints |
| `lib/ui/widgets/entry_form/entry_form_edit_sheet.dart` | **Create** | Edit mode: `_selectedType`, `_isSaving`, `_richContent` state, save with tag extraction + provider invalidation |
| `lib/ui/widgets/entry_form/tag_autocomplete_field.dart` | **Create** | `TextField` + suggestion chip. Receives `editorHashTagPartial` via constructor. Computes `_unifiedSuggestion`. Emits `onAcceptSuggestion` |
| `lib/ui/widgets/entry_form/entry_type_selector.dart` | **Create** | Unified `PopupMenuButton<EntryType?>`. Props: `currentType`, `isManual`, `onSelected`, `showAutoOption`. Static helpers `_iconForType`/`_labelForType` |
| `lib/ui/widgets/entry_form/quick_commands_sheet.dart` | **Create** | Extracted `_showQuickCommands` as `QuickCommandsSheet.show(context)`. `_CommandEntry` made public |

No caller changes needed — `EntryFormSheet` stays at the same path with identical constructor.

## Interfaces / Contracts

```dart
// ── Orchestrator (unchanged public API) ──
class EntryFormSheet extends ConsumerStatefulWidget {
  final Entry? entry;
  final String? entryId;
  final Future<void> Function()? onCredentialRequested;
  // constructor unchanged
}

// ── TagAutocompleteField ──
class TagAutocompleteField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String? editorHashTagPartial;
  final ValueChanged<String> onChanged;
  final ValueChanged<TagSetting> onAcceptSuggestion;
}

// ── EntryTypeSelector ──
class EntryTypeSelector extends StatelessWidget {
  final EntryType? currentType;
  final bool isManual;
  final ValueChanged<EntryType?> onSelected;
  final bool showAutoOption;
  // Static: _iconForType(EntryType), _labelForType(EntryType)
}

// ── QuickCommandsSheet ──
class QuickCommandsSheet extends StatelessWidget {
  static void show(BuildContext context);
}
```

No new provider or controller interfaces — all existing Riverpod providers (`createEntryControllerProvider`, `tagSettingsListProvider`) stay unchanged.

## Draft Lifecycle Flow

```
EntryFormCreateSheet.initState:
  → if !_isEditing:
      → ref.read(entryDraftProvider.notifier)
      → ref.read(createEntryControllerProvider.notifier)
      → Future.microtask → _restoreDraft()
        → ref.read(entryDraftProvider)
        → populate _titleCtrl, _tagsCtrl, _controller.loadDraft()

EntryFormCreateSheet.dispose:
  → if !_didSaveSuccessfully && hasContent:
      → Future.microtask → _draftNotifier.save(draft)
  → elif !_didSaveSuccessfully:
      → Future.microtask → _draftNotifier.clear()
  → _titleCtrl.dispose(); _tagsCtrl.dispose()
```

Exact same timing (`Future.microtask`) and guard flag (`_didSaveSuccessfully`) as current code — moved entirely from `_EntryFormSheetState` to `EntryFormCreateSheet`.

## Testing Strategy

| Layer | What | Approach |
|-------|------|----------|
| Widget — Create | Draft restore on open | Pump `EntryFormCreateSheet` with overridden `entryDraftProvider`, verify TextField values |
| Widget — Create | Draft save on dismiss | Type, dismiss, read provider state |
| Widget — Create | No draft on empty dismiss | Close without typing, verify null |
| Widget — Create | Cancel button clears draft | Tap Cancel, verify draft cleared |
| Widget — Edit | Load entry data | Pump `EntryFormEditSheet` with `Entry` fixture, verify fields populated |
| Widget — Edit | Save with tag merge | Fill fields, tap Save, verify `updateEntryProvider` called with merged tags |
| Widget — Edit | Save invalidation | After save, verify `entryDetailProvider`, `entryListProvider` invalidated |
| Widget — TagAuto | Editor tag suggested | Set `editorHashTagPartial`, verify suggestion chip renders |
| Widget — TagAuto | Accept editor suggestion | Tap chip, verify `acceptTagSuggestion` called on editor state |
| Widget — TypeSelector | All types listed | Pump `EntryTypeSelector`, verify 5 `EntryType` items |
| Widget — TypeSelector | Credential selection | Select credential, verify `onSelected(credential)` callback |
| Widget — Commands | Help sheet renders | Call `QuickCommandsSheet.show`, verify command entries listed |

Existing tests (`create_entry_controller_test.dart`, `entry_detail_view_test.dart`, `create_entry_sheet_test.dart`) should pass unchanged — internal refactoring only.

## Migration / Rollout

No migration required. Pure extract + delegate refactoring. Deploy all files in one commit; orchestrator keeps same filename and public API. Rollback: revert `entry_form_sheet.dart` and delete `lib/ui/widgets/entry_form/`.

## Open Questions

- [ ] Should `CreateEntrySheet` (thin wrapper in `lib/ui/screens/`) be eliminated, making `EntryFormSheet(onCredentialRequested: ...)` the entry point directly? Keep for now as documented import to avoid unnecessary diff.
- [ ] TagAutocompleteField — does it accept `editorHashTagPartial` as constructor arg or as a Stream? Constructor arg is simpler and matches current pattern.
