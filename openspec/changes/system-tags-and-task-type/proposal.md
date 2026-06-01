# Proposal: System Tags and Task Type

## Intent
Add `EntryType.task` with `DateTime? completedAt` and a set of immutable system tags (`#pendiente`, `#completada`, `#favorito`, `#archivado`) that provide cross-cutting behavior across all entry types.

## Scope
- **New Capability**: `task-type` — new entry type, completedAt field, database migration
- **New Capability**: `system-tags` — immutable tags with reserved colors, sin-color behavior, auto-assignment, exclusive section in tag management
- **Modified Capability**: `entry-model` — add `completedAt` field, system tags semantics
- **Modified Capability**: `tag-management` — show system tags in separate section, only color editable, sin-color resets to default
- **Modified Capability**: `type-filter` — add Task to SnakeFab type filter
- **Modified Capability**: `tag-filter` — show system tags in SnakeFab tag filter
- **Affected Layers**: domain (entities, usecases), infrastructure (database, migration), ui (providers, screens, widgets)

## Design Decisions (agreed with user)

### Task Type
- EntryType.task added to enum; DateTime? completedAt added to Entry entity
- Schema version from 7 → 8 (Drift migration adding completed_at column)
- NO subtasks, NO due dates, NO notifications in this version
- Tasks render identically to other entries in the list (no visual distinction beyond type badge)
- Filter by type via existing SnakeFab: Notes / Ideas / Glossary / Tasks / All
- Auto-assign #pendiente system tag on Task creation
- Mark as complete: #pendiente → #completada, set completedAt = now
- If #pendiente is removed from a task without #completada, it gets re-added automatically

### System Tags
- Four immutable system tags: #pendiente, #completada, #favorito, #archivado
- Cannot be renamed, deleted, or have their text edited
- Only editable property: color (and only via tag management UI)
- Default colors are EXCLUDED from the normal PalettePicker palette
- If user chooses "sin color" (new option in PalettePicker), tag reverts to its default color
- System tags appear in a SEPARATE section in tag management screen (not mixed with user tags)
- They are NOT shown in the normal tag list in management; they have their own section
- User can change their color freely, but every time they pick "sin color" it goes back to the default
- #pendiente and #completada are auto-managed (see Task Type above)
- #favorito is manual toggle from entry detail or card
- #archivado is manual toggle; archived entries are hidden from main view but still findable via search and tag filter
- All four system tags appear in the SnakeFab tag filter normally
- PalettePicker needs a "sin color" option (null color) that for system tags means "reset to default"

### Existing Features Affected
- PalettePicker: add a "sin color" / no-color option
- TagManagementScreen: add system tags section header, only color editable, remove/rename disabled
- EntryCard/EntryDetailView: add #favorito toggle, #archivado toggle
- SnakeFab tag filter: include system tags
- SnakeFab type filter: include Task
- Entry model: add completedAt, consider system tags in copyWith/comparison
- Home list view: hide archived entries by default, add toggle or filter for archived

## Rollback
- Migration can be reversed (schema 7 → 8 is additive: new column + system tag inserts)
- System tags are purely additive data; removing them requires a data migration
- Task type removal is breaking; existing tasks would need type migration to Note
