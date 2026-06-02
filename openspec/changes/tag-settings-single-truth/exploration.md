## Exploration: TagSettings single source of truth for tag colors

### Current State

Tag colors are stored in **two parallel sources** with no cross-sync:

| Source | Column | Format | Written by |
|--------|--------|--------|------------|
| `entries` table | `tags_color` (added migration v6) | JSON `Map<tagName, hex>` — per-entry | Entry detail long-press palette picker |
| `tag_settings` table | `color` (added migration v7) | `VARCHAR?` — one per tag | Tag management screen ("Gestión de etiquetas") |

**Color resolution flows (end-to-end):**

1. **Entry background / card display color** → `entryDisplayColorProvider` in `color_providers.dart`:
   - Reads `entry.tagsColors` (deserialized from `entries.tags_color` column)
   - Maps each tag → hex via `entry.tagsColors[t]`, parses to `Color`, passes to `TagColorMixer.mix()`
   - **Source: `entries.tags_color` only** — never consults `tag_settings`

2. **Individual tag chip color in detail view** → `tagColorForEntryProvider`:
   - Reads `entry.tagsColors[tag]` from the same per-entry map
   - **Source: `entries.tags_color` only**

3. **Tag filter pills / FAB colors in home view** → `tagColorMapProvider`:
   - Reads `tagSettingsMapProvider` which reads `tag_settings.color`
   - **Source: `tag_settings` only** — there's a comment about fallback to entry-scanned but the code does not implement it

**Write paths:**

- **Entry detail palette picker** (both `_NoteContent` and `_CredentialContent`):
  1. User long-presses a tag chip → palette picker dialog
  2. Reads current color from `entry.tagsColors[tagName]`
  3. User selects a color
  4. Writes to **current entry** via `updateEntryTagsColorsProvider` → `UpdateEntryTagsColors` use case → `EntryRepositoryImpl.updateTagsColors` → `EntryDao.updateTagsColors` → writes `entries.tags_color` JSON
  5. **Propagates to ALL entries** sharing that tag — iterates `entryListProvider` and writes the same color per-entry via the same use case
  6. **Does NOT write to `tag_settings` at all**

- **Tag management screen palette picker** (`_showColorPicker` in `_TagSettingTile`):
  1. User taps a tag tile → palette picker dialog
  2. Reads current color from `setting.color` (from `tag_settings` table)
  3. User selects a color
  4. Writes to `tag_settings` via `saveTagSettingProvider` → `SaveTagSetting` use case → `TagSettingsRepositoryImpl.save` → `TagSettingsDao.upsert`
  5. **Does NOT update `entries.tags_color` at all**

**System tags** (`pendiente`, `completada`, `favorito`, `archivado`):
- Seeded in migration v8 and `onCreate` with reserved default colors from `TagPalette.systemTagDefaults`
- Both palette pickers have special handling: "sin color" for a system tag reverts to `TagPalette.systemTagDefaults[tagName.toLowerCase()]` (compile-time constant, not read from DB)

**Key observation**: the `EntryDao._syncTags()` method syncs tag **names** to `TagSettings` when an entry is inserted/updated (via `_tagSettingsDao.upsert(tag)`), but it does NOT pass a `color` parameter. Colors are never synced between the two sources.

### Affected Areas

All files that would need changes, ordered by layer:

| # | File | Role | Change needed |
|---|------|------|---------------|
| 1 | `lib/domain/entities/entry.dart` | Domain entity with `tagsColors` field | Field may become unused — deprecate/remove |
| 2 | `lib/domain/repositories/i_entry_repository.dart` | Entry repo interface with `updateTagsColors` | Remove method |
| 3 | `lib/domain/usecases/update_entry_tags_colors.dart` | Use case wrapping old write path | Remove file |
| 4 | `lib/infrastructure/database/entry_dao.dart` | DAO with `updateTagsColors` and `_fromMap`/`_toCompanion` tag color handling | Remove `updateTagsColors`, simplify `_fromMap`/`_toCompanion` |
| 5 | `lib/infrastructure/database/entry_repository_impl.dart` | Repository impl delegating to DAO | Remove `updateTagsColors` override |
| 6 | `lib/infrastructure/database/entries_table.dart` | Drift table with `tagsColor` column | Remove column (future migration v9) |
| 7 | `lib/ui/providers/color_providers.dart` | `entryDisplayColorProvider`, `tagColorForEntryProvider`, `tagColorMapProvider` | Change readers to use `tagSettingsMapProvider` instead of `entry.tagsColors` |
| 8 | `lib/ui/providers/entry_providers.dart` | `updateEntryTagsColorsProvider` | Remove provider |
| 9 | `lib/ui/screens/entry_detail_view.dart` | Two copies of `_showPalettePicker` (lines 552, 1132) | Change to write to `tag_settings` instead of per-entry `tags_color`; remove propagation loop |
| 10 | `lib/domain/entities/tag_setting.dart` | `TagSetting.color` field | Already exists — no change needed |
| 11 | `lib/domain/repositories/i_tag_settings_repository.dart` | `updateColor` method | Already exists — may be used directly |
| 12 | `lib/infrastructure/database/tag_settings_dao.dart` | `updateColor` method | Already exists — no change needed |
| 13 | `lib/infrastructure/database/app_database.dart` | Migration 6-8 | Add migration v9 to drop `tags_color` |
| 14 | `test/` — color provider tests | No existing tests | Add tests for refactored providers |

**Consumer files (no logic change, just benefit from single source):**
- `lib/ui/screens/home_view.dart` — uses `entryDisplayColorProvider` and `tagColorMapProvider`
- `lib/ui/widgets/filter_chips.dart` — uses `tagColorMapProvider`

### Approaches

#### 1. Dual-write bridge (safer migration)

Keep reading from `entries.tags_color` for entry-level display, but make the palette picker write to BOTH sources. Then migrate readers one at a time to `tag_settings`.

**Implementation:**
1. In `_showPalettePicker`, after writing to `entries.tags_color`, also call `saveTagSettingProvider` to update `tag_settings.color`
2. Later, migrate `entryDisplayColorProvider` and `tagColorForEntryProvider` to read from `tag_settings`
3. Finally, remove `entries.tags_color` column

| Pros | Cons | Effort |
|------|------|--------|
| Gradual — each change independently verifiable | Two writes for every color change (extra latency) | **Medium** |
| Low risk — existing behavior preserved during migration | Temporary duplication adds cognitive load | 3-4h for bridge phase |
| Easy rollback — revert to old readers | Propagation loop still does N writes + tag_settings write = N+1 writes | 1-2h for reader migration |

#### 2. Direct switch — TagSettings is the single source of truth (recommended)

In one atomic change:
1. Rewrite both `_showPalettePicker` copies to write color to `tag_settings` instead of per-entry `entries.tags_color`
2. Rewrite `entryDisplayColorProvider` and `tagColorForEntryProvider` to read from `tagSettingsMapProvider` instead of `entry.tagsColors`
3. Remove `updateTagsColors` pipeline (use case, repo method, DAO method, provider)
4. Add a one-time data-fill migration: populate `tag_settings.color` from a deduplicated scan of existing `entries.tags_color` data (already partially done in migration v7, but may have diverged since)
5. Drop `entries.tags_color` column in a future migration

| Pros | Cons | Effort |
|------|------|--------|
| Single source of truth from day one | Breaks the theoretical scenario of different colors for same tag across entries | **Medium-High** |
| Eliminates the N-entry propagation loop — one write instead of N+1 | Needs careful QA on migration to avoid data loss | 4-6h |
| Cleaner data model, less code | All-or-nothing switch (harder rollback mid-flight) | |
| `tagColorMapProvider` already reads from `tag_settings` — half the work is done | | |

**Key risk analysis for "different colors per tag per entry":**
- The current palette picker ALREADY propagates the same color to all entries sharing that tag — so in practice the data should already be consistent
- The only divergence would be from direct DB manipulation or from a buggy intermediate state
- Acceptable risk given the long-press already enforces global consistency

### Recommendation

**Approach 2 — Direct switch.** Here's why:

1. **Half the work is already done**: `tagColorMapProvider` and all filter/FAB consumers already read from `tag_settings`. The display color providers are the only readers still on `entries.tags_color`.

2. **The propagation loop is a code smell**: iterating ALL entries and doing N writes per color change is slow and wasteful. With TagSettings as source, one write = all entries reflect the new color instantly via Riverpod invalidation.

3. **No real divergence risk**: the existing UX already enforces global color per tag (the propagation loop). The data model just needs to catch up to the UX intent.

4. **Dead code elimination**: removing `updateTagsColors`, its use case, its repo method, and its DAO method simplifies the codebase.

**Migration data safety:**
- Before the switch, run a one-time pass that reads all existing `entries.tags_color` data, deduplicates by tag name (first or most common wins), and writes to `tag_settings` where `tag_settings.color` is currently `null`. This catches any entries whose colors were set before migration v7 ran.
- After the switch, the `entries.tags_color` column stores vestigial data. Add migration v9 to drop the column (separate PR to keep this one focused).

### Risks

- **Data loss without fill migration**: existing `entries.tags_color` data that hasn't been synced to `tag_settings` would become invisible. **Mitigation**: run a one-time fill as described above.
- **System tag color reset**: if a system tag has a color in `tag_settings` but the palette picker reads from `entry.tagsColors[tag]` and that entry doesn't have that tag color set, the display falls to null → `TagPalette.defaultGrey`. After the switch, it'll correctly read from `tag_settings`. This is actually a bugfix, not a regression.
- **Performance**: `tagColorForEntryProvider` currently does a per-tag lookup in the entry's tagsColors map (O(1)). Switching to `tagSettingsMapProvider` is also O(1) map lookup. No performance concern.
- **tagColorMapProvider already reads from tag_settings**: it uses the same `tagSettingsMapProvider` that the refactored providers will use. So filter/FAB display is already on the new source.

### Ready for Proposal

Yes. The exploration is complete and the path is clear — proceed to `sdd-propose` with Approach 2 (direct switch) as the recommended strategy.

**What the orchestrator should tell the user**: We have full visibility into the dual-source problem. The fix is well-scoped: rewrite two readers (`entryDisplayColorProvider`, `tagColorForEntryProvider`) and two writers (the two `_showPalettePicker` methods) plus remove the old `updateTagsColors` pipeline. Approx 4-6 hours of work with one-time data-fill migration to prevent data loss.
