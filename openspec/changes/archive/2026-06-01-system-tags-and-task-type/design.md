# Design: System Tags and Task Type

## Technical Approach

Extend `EntryType` enum with `task`, add `DateTime? completedAt` to the `Entry` entity and the `entries` table (Drift schema 7→8). Introduce `isSystem` flag on `TagSetting` domain entity and `is_system` column on `tag_settings` table. Seed 4 system tags in migration with default colors from `TagPalette`. Add `#pendiente` auto-assignment in `CreateEntry` for tasks, `#pendiente`→`#completada` completion logic, and `#archivado` filter in the list query. Modify UI at 5 touch points: `TagManagementScreen` (sectioned, immutable), `PalettePicker` ("sin color" option), `SnakeFab` (Task type, system tags), `EntryCard` (favorito/archivado toggles), and `CreateEntrySheet` (task type).

## Architecture Decisions

| Decision | Options | Choice | Rationale |
|----------|---------|--------|-----------|
| completedAt storage | Inline on Entry vs separate table | **Inline** — single field, no join cost, matches existing pattern |
| System tag identification | Reserved names vs is_system flag | **is_system flag** — explicit, queryable, prevents name-collision bugs |
| Default color storage | Hard-coded in UI vs in DB | **Hard-coded in `TagPalette`** + DB stores override — system tags always have a fallback even before user assigns a color |
| Auto-reattach #pendiente | In use case vs DB trigger | **In `UpdateEntry` use case** — explicit, testable, no hidden DB magic |
| Completion flow | New use case vs inline in `UpdateEntry` | **`MarkAsCompleted` use case** — encapsulate the invariant: #pendiente→#completada + completedAt=now |
| Archived filter | UI-side filter vs DAO query param | **DAO query param `excludeArchived`** — filters at source, no unnecessary data transfer |

## Data Flow

```
1. Create Task
   CreateEntry (domain) ──auto-add #pendiente──→ EntryRepository ──→ EntryDao ──→ AppDatabase

2. Mark Complete
   MarkAsCompleted (new) ──#pendiente→#completada + completedAt──→ UpdateEntry ──→ DB

3. Update Entry (task without #completada)
   UpdateEntry ──detect missing #pendiente──→ re-attach #pendiente silently

4. Toggle #favorito / #archivado
   EntryCard ──onTap──→ ToggleTag (new) ──add/remove──→ UpdateEntry

5. List entries (main view)
   filteredEntriesProvider ──→ ListEntries ──→ EntryDao.list(excludeArchived:true)
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/domain/entities/entry_type.dart` | Modify | Add `EntryType.task('TAREA')` |
| `lib/domain/entities/entry.dart` | Modify | Add `DateTime? completedAt` field |
| `lib/domain/entities/tag_setting.dart` | Modify | Add `bool isSystem` field |
| `lib/domain/usecases/create_entry.dart` | Modify | Auto-add `#pendiente` when type == task |
| `lib/domain/usecases/update_entry.dart` | Modify | Re-attach `#pendiente` if removed without `#completada` |
| `lib/domain/usecases/mark_as_completed.dart` | Create | New use case: toggle `#pendiente`→`#completada` + set completedAt |
| `lib/domain/usecases/toggle_entry_tag.dart` | Create | Add/remove single system tag (#favorito, #archivado) |
| `lib/domain/repositories/i_entry_repository.dart` | Modify | Add `excludeArchived` param to `list()` |
| `lib/domain/repositories/i_tag_settings_repository.dart` | Modify | Add `getSystemTags()`, `seedSystemTags()` |
| `lib/infrastructure/database/entries_table.dart` | Modify | Add `DateTimeColumn? completedAt` |
| `lib/infrastructure/database/tag_settings_table.dart` | Modify | Add `BoolColumn isSystem` |
| `lib/infrastructure/database/app_database.dart` | Modify | Schema 7→8: add completed_at, is_system, seed 4 system tags |
| `lib/infrastructure/database/entry_dao.dart` | Modify | Handle completedAt in `_toCompanion`/`_fromMap`, add `excludeArchived` param |
| `lib/infrastructure/database/entry_repository_impl.dart` | Modify | Pass `excludeArchived` through |
| `lib/infrastructure/database/tag_settings_dao.dart` | Modify | Add `getSystemTags()`, `getUserTags()` |
| `lib/infrastructure/database/tag_settings_repository_impl.dart` | Modify | Wire new methods, map `isSystem` |
| `lib/shared/tag_palette.dart` | Modify | Add `static const Map<String, PaletteColor> systemTagDefaults` |
| `lib/ui/widgets/palette_picker.dart` | Modify | Add "sin color" option, support `isSystemTag` context |
| `lib/ui/screens/tag_management_screen.dart` | Modify | Split into system/user sections, disable rename/delete for system tags |
| `lib/ui/screens/home_view.dart` | Modify | Add Task to type filter SnakeFab, include system tags in tag filter |
| `lib/ui/providers/entry_providers.dart` | Modify | Add `selectedTypeFilter` for Task, `excludeArchived` in list query |
| `lib/ui/providers/tag_settings_providers.dart` | Modify | Add system/user tag providers |
| `lib/ui/widgets/entry_card.dart` | Modify | Add type icon for task, favorito/archivado toggle icons |

## Interfaces / Contracts

```dart
// Domain
class MarkAsCompleted {
  Future<Entry> call(Entry entry);
}

class ToggleEntryTag {
  Future<Entry> call(Entry entry, String tagName, bool add);
}

// Repository extension
abstract class IEntryRepository {
  Future<List<Entry>> list({
    EntryType? type,
    bool includeDeleted = false,
    bool excludeArchived = false,  // NEW
  });
}

abstract class ITagSettingsRepository {
  Future<List<TagSetting>> getSystemTags();       // NEW
  Future<List<TagSetting>> getUserTags();          // NEW
  Future<void> seedSystemTags();                   // NEW
}
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `CreateEntry` with task type — asserts `#pendiente` in tags | Use mock `IEntryRepository`, verify tag list |
| Unit | `UpdateEntry` — remove #pendiente without #completada → re-attached | Verify final tags still contain `pendiente` |
| Unit | `UpdateEntry` — remove #pendiente when #completada present → stays removed | Verify no re-attach |
| Unit | `MarkAsCompleted` — #pendiente replaced, completedAt set | Verify final state |
| Unit | `ToggleEntryTag` — add/remove #favorito, #archivado | Verify tag changes |
| Unit | `TagSetting` entity — `isSystem` flag serialization | Verify fromMap/toMap |
| Integration | DB migration 7→8: columns exist, system tags seeded | `AppDatabase.custom()` with in-memory, check schema |
| Integration | `EntryDao.list(excludeArchived: true)` excludes #archivado entries | Seed entries, verify filtered count |
| Widget | `PalettePicker` — "sin color" renders, calls callback with null | `pumpWidget`, verify tap |
| Widget | `TagManagementScreen` — system section header, no delete/rename for system | Verify widgets absent |
| Widget | `SnakeFab` type filter — Task item present | Verify item list includes task |

## Migration / Rollout

**Schema 7→8 (additive)**: Add `completed_at TEXT` to `entries`, add `is_system INTEGER DEFAULT 0` to `tag_settings`. Insert 4 system tags with `is_system=1` and default colors. Rollback is schema 8→7 (drop columns + delete system tag rows). Existing data unaffected — all existing entries get `completed_at = NULL`, existing tag_settings get `is_system = 0`.

## Open Questions

None.
