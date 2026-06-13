# Spec: Delete Selected Tags

## Overview

Delta spec for adding multi-select batch delete to the tag management screen. All changes are UI-only — no domain or infrastructure layers are affected. Reuses existing `DeleteTagSetting` and `removeTagFromEntries` use cases.

## Requirements

### R1: Multi-Select Mode

The system SHALL support a multi-select mode on the tag management screen, activated by long-pressing any non-system user tag.

- While in multi-select mode, tapping a user tag SHALL toggle its selection state.
- System tags (`isSystem == true`) MUST NOT be selectable — long-press on a system tag SHALL have no effect (existing color-picker behavior unchanged).
- A selected tag SHALL display a checkmark overlay on its leading icon.
- The user SHALL exit multi-select mode via:
  - Pressing the back button in the app bar, or
  - Clearing all selections (last item deselected).

#### Scenario: Enter multi-select via long-press

- GIVEN the user is on the tag management screen with 3+ user tags
- WHEN the user long-presses a user tag
- THEN that tag SHALL become selected with a checkmark overlay
- AND the screen SHALL enter multi-select mode

#### Scenario: Toggle selection in multi-select mode

- GIVEN the user is in multi-select mode with 1 tag selected
- WHEN the user taps another user tag
- THEN that tag SHALL toggle its selection state
- AND previously selected tags SHALL remain selected

#### Scenario: System tag not selectable

- GIVEN the user is in multi-select mode
- WHEN the user taps a system tag tile
- THEN the system tag SHALL NOT toggle selection
- AND existing selections SHALL remain unchanged

#### Scenario: Exit multi-select via back button

- GIVEN the user is in multi-select mode with 2+ tags selected
- WHEN the user presses the back button
- THEN multi-select mode SHALL exit
- AND all selections SHALL be cleared

#### Scenario: Auto-exit on last deselection

- GIVEN the user is in multi-select mode with exactly 1 tag selected
- WHEN the user taps that tag to deselect it
- THEN multi-select mode SHALL exit
- AND the normal single-tag UI SHALL be restored

### R2: Delete Action Bar

When one or more tags are selected, the system SHALL display a bottom action bar with:
- A count label: `"{N} tag(s) seleccionados"` (singular/plural in Spanish).
- A delete button with a trash icon (`Icons.delete`) styled in the error color.
- A cancel button with an X icon (`Icons.close`).

The action bar SHALL animate in from the bottom. The system SHALL remove the action bar when selection is cleared or multi-select mode exits.

#### Scenario: Action bar appears on selection

- GIVEN the user selects 1 user tag in multi-select mode
- THEN a bottom action bar SHALL appear with label `"1 tag seleccionado"`
- AND a delete button SHALL be visible
- AND a cancel button SHALL be visible

#### Scenario: Action bar count updates

- GIVEN the user has selected 2 tags
- THEN the label SHALL read `"2 tags seleccionados"`
- WHEN the user selects a third tag
- THEN the label SHALL update to `"3 tags seleccionados"`

#### Scenario: Action bar hides on cancel

- GIVEN the action bar is visible with tags selected
- WHEN the user taps the cancel (X) button
- THEN multi-select mode SHALL exit
- AND the action bar SHALL disappear
- AND all selections SHALL be cleared

### R3: Confirmation Dialog

When the user taps the delete button, the system SHALL show an AlertDialog:

- **Title**: `"¿Eliminar tag(s)?"` (singular/plural).
- **Content**: `"Se eliminarán N tag(s) y se desvincularán de todas las entradas."`
- **Actions**:
  - `"Cancelar"` — outlined button, dismisses dialog, stays in multi-select mode.
  - `"Eliminar"` — filled button with error background, confirms deletion.

System tags MUST never appear in this dialog — they are filtered out at selection time (see R1).

#### Scenario: Confirmation dialog shows correct count

- GIVEN 3 user tags are selected
- WHEN the user taps the delete button
- THEN a confirmation dialog SHALL appear with title `"¿Eliminar tags?"`
- AND content SHALL include `"Se eliminarán 3 tags"`

#### Scenario: Cancel keeps selection

- GIVEN the confirmation dialog is shown with 2 tags selected
- WHEN the user taps `"Cancelar"`
- THEN the dialog SHALL dismiss
- AND the 2 tags SHALL remain selected
- AND multi-select mode SHALL remain active

#### Scenario: Confirm proceeds to delete

- GIVEN the confirmation dialog is shown
- WHEN the user taps `"Eliminar"`
- THEN the system SHALL proceed with batch deletion (see R4)

### R4: Batch Delete Execution

Upon confirmation, the system SHALL iterate over each selected tag and:

1. Call `DeleteTagSetting` use case with the tag name.
2. Call `removeTagFromEntries` use case to unlink from all entries.
3. Collect all affected entry IDs.

After all tags are processed, the system SHALL:
1. Deduplicate the collected entry IDs.
2. Invalidate `tagSettingsListProvider`.
3. Invalidate `entryListProvider`.
4. Invalidate `entryDetailProvider(id)` for each affected entry ID.
5. Exit multi-select mode.
6. Display a SnackBar: `"{N} tag(s) eliminados"`.

#### Scenario: Batch delete execution

- GIVEN the user has selected 2 user tags
- AND the user confirmed deletion
- WHEN the batch delete executes
- THEN `DeleteTagSetting` SHALL be called once per tag
- AND `removeTagFromEntries` SHALL be called once per tag
- AND all affected entry IDs SHALL be collected and deduplicated
- AND `tagSettingsListProvider` SHALL be invalidated
- AND `entryListProvider` SHALL be invalidated
- AND `entryDetailProvider` for each affected ID SHALL be invalidated
- AND multi-select mode SHALL exit
- AND a SnackBar `"2 tags eliminados"` SHALL be shown

#### Scenario: Deduplicate shared entry IDs

- GIVEN 2 selected tags that both appear on the same entry
- WHEN batch delete executes
- THEN `entryDetailProvider` for that shared entry SHALL be invalidated only once

### R5: Error Handling

If a tag's deletion fails (either `DeleteTagSetting` or `removeTagFromEntries` throws), the system SHALL:
1. Log the error.
2. Skip to the next tag (continue processing remaining tags).
3. After all tags complete, show a partial-success SnackBar if some failed: `"Se eliminaron M de N tag(s)"`.
4. If ALL deletions fail, show: `"No se pudieron eliminar tags"`.

#### Scenario: Partial success

- GIVEN the user selected 3 tags
- AND tag 2 fails to delete
- WHEN batch delete completes
- THEN the system SHALL show SnackBar `"Se eliminaron 2 de 3 tags"`

#### Scenario: All fail

- GIVEN the user selected 2 tags
- AND both tags fail to delete
- WHEN batch delete completes
- THEN the system SHALL show SnackBar `"No se pudieron eliminar tags"`
- AND multi-select mode SHALL exit

## Scenarios

| # | Scenario | GIVEN | WHEN | THEN |
|---|----------|-------|------|------|
| 1 | Enter multi-select via long-press | User on tag management screen with 3+ user tags | Long-presses a user tag | Tag selected with checkmark; enters multi-select mode |
| 2 | Toggle selection | In multi-select with 1 selected | Taps another user tag | That tag toggles; prior selections kept |
| 3 | System tag not selectable | In multi-select mode | Taps system tag | No selection change |
| 4 | Exit via back button | In multi-select with 2+ selected | Presses back (app bar) | Exits mode; clears all selections |
| 5 | Auto-exit on last deselect | In multi-select with exactly 1 selected | Taps that tag to deselect | Exits mode; normal UI restored |
| 6 | Action bar appears | Selects 1 user tag | — | Bottom bar: `"1 tag seleccionado"`, delete + cancel buttons |
| 7 | Action bar count updates | 2 tags selected | Selects a third | Label updates to `"3 tags seleccionados"` |
| 8 | Action bar hides on cancel | Action bar visible with selections | Taps cancel (X) | Exits mode; clears selections |
| 9 | Confirmation dialog shows | 3 tags selected | Taps delete | Dialog: `"¿Eliminar tags?"` with count |
| 10 | Cancel keeps selection | Confirmation shown | Taps "Cancelar" | Dismisses; stays in multi-select |
| 11 | Full batch delete | 2 tags selected, confirmed | Batch executes | Each tag deleted+unlinked; providers invalidated; snackbar shown |
| 12 | Deduplicate shared entries | 2 tags on same entry | Batch executes | Per-entry provider invalidated once |
| 13 | Partial success | 3 selected, 1 fails | Batch completes | SnackBar: `"Se eliminaron 2 de 3 tags"` |
| 14 | All fail | 2 selected, both fail | Batch completes | SnackBar: `"No se pudieron eliminar tags"`; exits mode |

## Non-Goals

- Tag editing (rename, recolor) — already exists via individual actions.
- Undo / rollback — future enhancement.
- Tag deletion from entry detail screen — separate feature.
- Selection persistence across screen revisits.
- Batch operations other than delete (e.g., batch tag rename or recolor).
