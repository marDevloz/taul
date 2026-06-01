# System Tags Specification

## Purpose

Define four immutable system tags (`#pendiente`, `#completada`, `#favorito`, `#archivado`) with special lifecycle, restricted editability, and cross-cutting behavior across all entry types.

## Requirements

### Requirement: System tag immutability

The system SHALL define four system tags: `#pendiente`, `#completada`, `#favorito`, `#archivado`. These tags MUST NOT be renameable, deletable, or text-editable through the UI. Their `color` property MAY be edited.

The system SHALL seed these tags in the `tag_settings` table during migration to schema 8 with reserved default colors outside the normal 16-color `TagPalette`.

#### Scenario: System tags exist on migration

- GIVEN a database at schema version 7
- WHEN the database is upgraded to schema 8
- THEN `tag_settings` SHALL contain four rows: `#pendiente`, `#completada`, `#favorito`, `#archivado`

#### Scenario: Cannot rename system tag

- GIVEN a system tag is selected in the tag management screen
- WHEN the user attempts to rename it
- THEN the rename action MUST be rejected or disabled

#### Scenario: Cannot delete system tag

- GIVEN a system tag is selected in the tag management screen
- WHEN the user attempts to delete it
- THEN the delete action MUST be rejected or disabled

#### Scenario: Can change system tag color

- GIVEN a system tag in the tag management screen
- WHEN the user picks a new color from the palette
- THEN the tag's color SHALL update to the chosen value

#### Scenario: Sin color resets to default

- GIVEN a system tag whose color was previously changed
- WHEN the user selects "sin color" in the `PalettePicker`
- THEN the tag's color SHALL revert to its reserved default color

### Requirement: System tags section in tag management

The system MUST display system tags in a clearly separated section of the `TagManagementScreen`, distinct from user-created tags. The section SHALL indicate these tags are system-managed.

Only the color picker SHALL be actionable for system tag tiles. Rename and delete actions MUST NOT be available.

#### Scenario: System tags shown separately

- GIVEN the user opens the tag management screen
- WHEN system tags exist
- THEN they SHALL appear in their own titled section above or below user tags

#### Scenario: System tag tile has limited actions

- GIVEN a system tag tile is displayed
- WHEN the user examines its available actions
- THEN only color change SHALL be available
- AND rename SHALL be absent or disabled
- AND delete SHALL be absent or disabled

### Requirement: Favorito and archivado manual toggle

The system MUST provide a toggle for `#favorito` and `#archivado` on entry cards and the detail view. These SHALL be manual, with no automatic lifecycle.

Entries with `#archivado` MUST be excluded from the main list but SHALL remain discoverable via search and the SnakeFab tag filter.

#### Scenario: Toggle favorito

- GIVEN an entry in a card or detail view
- WHEN the user toggles favorito
- THEN `#favorito` SHALL be added to the entry's tags
- AND toggling again SHALL remove it

#### Scenario: Toggle archivado hides from main view

- GIVEN an entry in the main list
- WHEN the user toggles archivado
- THEN `#archivado` SHALL be added
- AND the entry SHALL disappear from the main list

#### Scenario: Archived entry still findable

- GIVEN an entry with `#archivado`
- WHEN the user searches or filters by `#archivado` in SnakeFab
- THEN the entry SHALL appear in results

### Requirement: System tags in tag filter

The system MUST include all four system tags in the SnakeFab tag filter alongside user-created tags.

#### Scenario: System tags listed in tag filter

- GIVEN the user opens the SnakeFab tag filter
- WHEN system tags exist
- THEN `#pendiente`, `#completada`, `#favorito`, and `#archivado` SHALL all appear in the tag list
