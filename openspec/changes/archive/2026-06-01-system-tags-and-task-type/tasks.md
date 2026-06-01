# Tasks: System Tags and Task Type

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 700–900 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 (Domain) → PR 2 (Infra) → PR 3 (UI) |
| Delivery strategy | auto-forecast |
| Chain strategy | feature-branch-chain |

Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

| Unit | Goal | PR | Base |
|------|------|----|------|
| 1 | Domain + palette | 1 | feature/tracker branch |
| 2 | Use cases + DB + DAOs | 2 | PR 1 branch |
| 3 | UI widgets + screens | 3 | PR 2 branch |

## Phase 1: Domain Foundation

- [x] 1.1 Add `EntryType.task('TAREA')` to `entry_type.dart`
- [x] 1.2 Add `DateTime? completedAt` to `Entry` freezed; run codegen
- [x] 1.3 Add `bool isSystem` to `TagSetting`
- [x] 1.4 Add `excludeArchived` to `IEntryRepository.list()`
- [x] 1.5 Add `getSystemTags()`, `getUserTags()`, `seedSystemTags()` to `ITagSettingsRepository`
- [x] 1.6 Add `systemTagDefaults` to `TagPalette`

## Phase 2: Domain Use Cases

- [x] 2.1 `CreateEntry`: auto-add `#pendiente` when `type == task`
- [x] 2.2 `UpdateEntry`: re-attach `#pendiente` if missing w/o `#completada`
- [x] 2.3 Create `MarkAsCompleted`: `#pendiente`→`#completada` + `completedAt = now`
- [x] 2.4 Create `ToggleEntryTag`: add/remove system tag

## Phase 3: Infrastructure

- [x] 3.1 Add `DateTimeColumn? completedAt` to `Entries` table
- [x] 3.2 Add `BoolColumn isSystem` to `TagSettings` table
- [x] 3.3 Migration 7→8: columns + seed 4 system tags in `app_database.dart`
- [x] 3.4 Handle `completedAt` + `excludeArchived` in `EntryDao`
- [x] 3.5 Add `getSystemTags()`, `getUserTags()` to `TagSettingsDao`
- [x] 3.6 Wire `excludeArchived` in `EntryRepositoryImpl`
- [x] 3.7 Map `isSystem` in `TagSettingsRepositoryImpl`

## Phase 4: UI

- [x] 4.1 Add "sin color" + `isSystemTag` to `PalettePicker`
- [x] 4.2 Split system/user sections; disable rename/delete for system in `TagManagementScreen`
- [x] 4.3 Add Task + system tags to `SnakeFab`
- [x] 4.4 Add task icon + favorito/archivado toggles to `EntryCard`
- [x] 4.5 Wire Task filter + archived filter in `HomeView`
- [x] 4.6 Wire `MarkAsCompleted`, `ToggleEntryTag`, `excludeArchived` in providers
- [x] 4.7 Add system/user tag providers

## Phase 5: Testing

- [x] 5.1 Unit: `CreateEntry` task — `#pendiente` auto-assigned (spec 1.4–1.5)
- [x] 5.2 Unit: `UpdateEntry` — re-attach; non-task unaffected (spec 1.3, 1.6)
- [x] 5.3 Unit: `MarkAsCompleted` — tag swap + `completedAt` (spec 1.2)
- [x] 5.4 Unit: `ToggleEntryTag` — add/remove (spec 2.6–2.7)
- [x] 5.5 Unit: `TagSetting` — `isSystem` serde round-trip
- [x] 5.6 Integration: Migration 7→8 — columns + 4 seeds (spec 1.1, 2.1)
- [x] 5.7 Integration: `EntryDao.list(excludeArchived:true)` (spec 2.8)
- [x] 5.8 Widget: `PalettePicker` — sin color callback (spec 2.5)
- [x] 5.9 Widget: `TagManagementScreen` — system section, no delete/rename (spec 2.2–2.4)
- [x] 5.10 Widget: `SnakeFab` — Task + system tags (spec 1.1, 2.10)
