# Design: Tag Super Powers

## Technical Approach

Five additive PRs, each independently reviewable. PR 1-2 are pure UI/infra patches. PR 3 introduces a new DB table and security model. PR 4-5 extend EntryCard and HomeView with new interaction modes. No refactoring of existing contracts — all changes are additive.

## Architecture Decisions

### Decision: `UpdateEntryTagsColors` as separate use case

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Add param to `UpdateEntry` to skip version bump | Couples concerns, makes caller responsible for knowing internal behavior | ❌ |
| New use case + repo method `updateTagsColors` | Single responsibility, clear intent, DAO-level direct write | ✅ |

**Rationale**: `UpdateEntry` always bumps version (lines 37-38 of `update_entry.dart`). A new UC that writes only `tagsColors` via a targeted DAO update avoids touching version/updatedAt at all — no risk of accidental bumps, no conditional logic.

### Decision: `tag_settings` table as tag color source of truth

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Keep per-entry tagsColors only | No migration needed, but no canonical color — divergent per-entry | ❌ |
| New table + migration + dual-write | Migration cost, but single source of truth enables tag-level metadata (security, delete) | ✅ |

**Rationale**: Per-entry `tagsColors` is denormalized. A `tag_settings` table gives us tag-level metadata (`is_secure`, `deleted_at`) and a canonical color. Dual-write during palette picker keeps backward compat.

### Decision: Effective auth as `requiresAuth || tag.is_secure`

**Choice**: Single boolean expression at the provider level.
**Rationale**: No new per-entry field. Provider computes: `entry.requiresAuth || any tag in entry.tags has is_secure`. Gate applies to list view expansion and credential reveal.

## Schema Changes

### New: `tag_settings` table (Drift)

```dart
class TagSettings extends Table {
  TextColumn get name => text()();           // PK
  TextColumn? get color => text().nullable();// hex, e.g. "#E06C75"
  BoolColumn get isSecure => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  @override Set<Column> get primaryKey => {name};
}
```

### Migration v6 → v7

1. Create `tag_settings` table
2. Scan `entries.tags_color`, extract unique `{tag → color}` pairs, INSERT into `tag_settings`
3. `tagsColorProvider` reads from `tag_settings` after migration

No entry data changes — `tagsColors` field and old `tags_color` column remain for backward compat.

## Data Flow

### PR 2 — Color Update Flow (no version bump)

```
PalettePicker → UpdateEntryTagsColors use case → IRepository.updateTagsColors(id, colors) → EntryDao.updateTagsColors() → UPDATE entries SET tags_color=? WHERE id=?
```

### PR 3 — Tag Auth Gate

```
EntryCard (build) → effectiveAuthProvider(entryId) → checks entry.requiresAuth || any tag in tag_settings.is_secure → lock overlay if true
```

## File Changes

| File | Action | PR |
|------|--------|----|
| `lib/ui/screens/entry_detail_view.dart` | Modify | 1 |
| `lib/domain/usecases/update_entry_tags_colors.dart` | Create | 2 |
| `lib/domain/repositories/i_entry_repository.dart` | Modify (add `updateTagsColors`) | 2 |
| `lib/infrastructure/database/entry_repository_impl.dart` | Modify | 2 |
| `lib/infrastructure/database/entry_dao.dart` | Modify (add `updateTagsColors`) | 2 |
| `lib/infrastructure/database/tag_settings_table.dart` | Create | 3 |
| `lib/infrastructure/database/tag_settings_dao.dart` | Create | 3 |
| `lib/infrastructure/database/app_database.dart` | Modify (register table, v7 migration) | 3 |
| `lib/domain/repositories/i_tag_settings_repository.dart` | Create | 3 |
| `lib/infrastructure/database/tag_settings_repository_impl.dart` | Create | 3 |
| `lib/domain/usecases/get_tag_settings.dart` | Create | 3 |
| `lib/domain/usecases/save_tag_setting.dart` | Create | 3 |
| `lib/domain/usecases/delete_tag_setting.dart` | Create | 3 |
| `lib/ui/providers/color_providers.dart` | Modify (read from tag_settings) | 3 |
| `lib/ui/providers/entry_providers.dart` | Modify (add tag providers) | 3 |
| `lib/ui/providers/tag_settings_providers.dart` | Create | 3 |
| `lib/ui/screens/settings_screen.dart` | Modify (add tag management section) | 3 |
| `lib/ui/screens/tag_management_screen.dart` | Create | 3 |
| `lib/ui/providers/effective_auth_provider.dart` | Create | 3 |
| `lib/ui/widgets/entry_card.dart` | Modify | 4 |
| `lib/ui/widgets/entry_expanded_content.dart` | Create | 4 |
| `lib/ui/screens/home_view.dart` | Modify (add select mode, merge) | 5 |
| `lib/ui/screens/merge_editor_screen.dart` | Create | 5 |
| `lib/shared/merge_service.dart` | Create | 5 |
| `openspec/changes/tag-super-powers/spec.md` | Update (expand PR 3-5 contracts) | 3-5 |

## Interfaces / Contracts

### New repository method (PR 2)

```dart
// IEntryRepository
Future<void> updateTagsColors(String id, Map<String, String> tagsColors);
```

### New use case (PR 2)

```dart
class UpdateEntryTagsColors {
  const UpdateEntryTagsColors({required IEntryRepository repository});
  Future<void> call(Entry entry, Map<String, String> tagsColors);
  // Copies entry with new tagsColors, writes via repository.updateTagsColors
  // Does NOT change version, updatedAt, or any other field
}
```

### New tag settings repository (PR 3)

```dart
abstract class ITagSettingsRepository {
  Future<List<TagSetting>> getAll();
  Future<TagSetting?> getByName(String name);
  Future<void> save(TagSetting setting);  // upsert
  Future<void> delete(String name);
}

class TagSetting {
  final String name;
  final String? color;
  final bool isSecure;
  final DateTime createdAt;
}
```

### Effective auth provider (PR 3)

```dart
final effectiveAuthProvider = Provider.autoDispose.family<bool, String>((ref, entryId) {
  final entry = ref.watch(entryDetailProvider(entryId)).valueOrNull;
  if (entry == null) return false;
  if (entry.requiresAuth) return true;
  final tagSettings = ref.watch(tagSettingsMapProvider);
  return entry.tags.any((t) => tagSettings[t]?.isSecure ?? false);
});
```

## Security Model

Per-tag `is_secure` flows through `effectiveAuthProvider`. When `is_secure` is true for any tag in an entry:

- **EntryCard** (PR 4): shows lock icon, single click shows "Requires master password" prompt instead of expanding
- **EntryDetailView** (PR 5 context): existing `requiresAuth` gating handles it — the provider already checks both conditions
- **Tag management** (PR 3): toggling `is_secure` requires master password via `CredentialProtectionController.requireMasterKey()`

Master password integration: tag management uses the existing `requireMasterKey` dialog from `CredentialProtectionController` — no new auth UI needed.

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `UpdateEntryTagsColors` (PR 2) | Mock repository, verify no version bump |
| Unit | `TagSettingsDao` CRUD (PR 3) | In-memory Drift, round-trip insert/read/update/delete |
| Unit | `effectiveAuthProvider` (PR 3) | Test `requiresAuth || is_secure` combinations |
| Unit | MergeService (PR 5) | Test concatenation format, empty input, 20-entry max |
| Widget | EntryCard expand (PR 4) | Test tap vs double-tap behavior |
| Widget | Tag management screen (PR 3) | Test CRUD dialogs, secure toggle |
| Integration | Migration v6→v7 (PR 3) | Create DB at v6 with data, upgrade, verify tag_settings populated |

## Migration / Rollout

**PR 3 only** has a schema migration (v6→v7). Rollback: `DROP TABLE IF EXISTS tag_settings` — entries unaffected. The migration copies but does NOT delete old `tags_color` data, so rollback is lossless.

## Open Questions

None — all decisions map to spec contracts.
