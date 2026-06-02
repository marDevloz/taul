# Design: TagSettings Single Source of Truth for Tag Colors

## Technical Approach

Direct switch in 5 sequenced steps: data-fill within migration v9 → reader providers switch → writer palette pickers switch → remove `updateTagsColors` pipeline → drop `tags_color` column. One write per color change, no propagation loop.

---

## Architecture Decisions

### Decision: Reader providers — switch to `tagSettingsMapProvider`

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Keep reading from `entry.tagsColors` | Dead code, dual source | ❌ |
| Read from `tagSettingsMapProvider` | Single source, clean invalidation via Riverpod cascade | ✅ |

Both `entryDisplayColorProvider` and `tagColorForEntryProvider` drop the `entry.tagsColors[tag]` lookup. Instead they watch `tagSettingsMapProvider` and find the color by `tag.toLowerCase()`.

`tagColorForEntryProvider` keeps its `(entryId, tag)` signature for minimal call-site changes but ignores `entryId` internally.

### Decision: Writer palette pickers — write to `tag_settings` via `saveTagSettingProvider`

Both `_showPalettePicker` copies (in `_NoteContent` and `_CredentialContent`) replace the N-entry propagation loop with a single `saveTagSettingProvider` call. System tag "sin color" reverts to `TagPalette.systemTagDefaults` as before, but writes that default to `tag_settings.color` instead of per-entry.

Single invalidation: `ref.invalidate(tagSettingsListProvider)` cascades through `tagSettingsMapProvider` → both color providers → all consumers rebuild.

### Decision: Data-fill within migration v9

Data-fill the `tag_settings.color` from existing `entries.tags_color` belongs **inside migration v9**, before the column drop — guaranteeing color data survives the column removal. Migration v7 already did a similar scan, but this catches entries created/modified between v7 and v9.

Alternative (standalone utility) rejected: would add another startup code path for a one-time operation. Inline in migration is simpler and atomic.

### Decision: `Entry.tagsColors` field stays as inert

The `Entry.tagsColors` field is not removed from the entity — it's too coupled (freezed, JSON serialization, tests). After migration v9 drops the column, `_fromDbEntry`/`_fromMap` set it to `const {}`. No provider reads it. Cleanup deferred to a future refactor.

---

## Data Flow

**Before:**

```
Palette picker → updateEntryTagsColorsProvider → N writes (all entries)
                                                     ↓
                                              entry.tagsColors (per-entry JSON)
                                                     ↓
                                              entryDisplayColorProvider
                                              tagColorForEntryProvider
```

**After:**

```
Palette picker → saveTagSettingProvider → 1 write to tag_settings.color
                                               ↓
                                        tagSettingsListProvider (invalidated)
                                               ↓
                                        tagSettingsMapProvider (recomputed)
                                               ↓
                                        entryDisplayColorProvider
                                        tagColorForEntryProvider
                                        tagColorMapProvider (unchanged)
```

---

## Riverpod Invalidation Chain

```
saveTagSettingProvider (DB write)
  → ref.invalidate(tagSettingsListProvider)
    → tagSettingsMapProvider (auto-rebuilds)
      → entryDisplayColorProvider (rebuilds mix color)
      → tagColorForEntryProvider (rebuilds chip colors)
      → tagColorMapProvider (rebuilds filter colors, unchanged logic)
```

No `entryListProvider` or `entryDetailProvider` invalidation needed — entry tags list doesn't change, only tag colors. The cascade handles everything.

---

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/ui/providers/color_providers.dart` | Modify | Switch both providers to `tagSettingsMapProvider` |
| `lib/ui/screens/entry_detail_view.dart` | Modify | Rewrite both `_showPalettePicker` — remove propagation loop, save to `tag_settings` |
| `lib/domain/usecases/update_entry_tags_colors.dart` | Delete | Dead code |
| `lib/ui/providers/entry_providers.dart` | Modify | Remove `updateEntryTagsColorsProvider` |
| `lib/domain/repositories/i_entry_repository.dart` | Modify | Remove `updateTagsColors` |
| `lib/infrastructure/database/entry_repository_impl.dart` | Modify | Remove `updateTagsColors` |
| `lib/infrastructure/database/entry_dao.dart` | Modify | Remove `updateTagsColors`, drop `tagsColor` from `_toCompanion`/`_fromDbEntry` |
| `lib/infrastructure/database/entries_table.dart` | Modify | Remove `tagsColor` column definition |
| `lib/infrastructure/database/app_database.dart` | Modify | Add migration v9 (data-fill + drop column), bump schema to 9 |
| `test/ui/providers/color_providers_test.dart` | Create | Unit tests for refactored providers |

---

## Interfaces / Contracts

No new interfaces. The refactored `entryDisplayColorProvider` changes from:

```dart
// Before
final entry = ref.watch(entryDetailProvider(entryId));
entry.tags.map((t) => entry.tagsColors[t]).whereType<String>()...
```

```dart
// After
final entry = ref.watch(entryDetailProvider(entryId));
final tagMap = ref.watch(tagSettingsMapProvider);
entry.tags.map((t) => tagMap[t.toLowerCase()]?.color).whereType<String>()...
```

---

## Migration v9 Details

```dart
if (from < 9) {
  // Step 1: Data-fill tag_settings.color from entries.tags_color
  final rows = await select(entries).get();
  for (final row in rows) {
    if (row.tagsColor == null) continue;
    final colors = Map<String, String>.from(
      Map<String, dynamic>.from(jsonDecode(row.tagsColor!)) as Map,
    );
    for (final tagName in colors.keys) {
      final existing = await (select(tagSettings)
        ..where((t) => t.name.equals(tagName))).getSingleOrNull();
      if (existing == null || existing.color == null) {
        await into(tagSettings).insertOnConflictUpdate(
          TagSettingsCompanion.insert(
            name: tagName,
            color: Value(colors[tagName]!),
          ),
        );
      }
    }
  }
  // Step 2: Drop column
  await customInsert('ALTER TABLE entries DROP COLUMN tags_color');
}
```

---

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `entryDisplayColorProvider` | Mock `entryDetailProvider` + `tagSettingsMapProvider`; verify mix color output for 0, 1, N tags |
| Unit | `tagColorForEntryProvider` | Mock `tagSettingsMapProvider`; verify resolved color per tag |
| Unit | Migration v9 | `AppDatabase.custom()` with schema v8, insert entries with `tags_color`, migrate to v9, verify data in `tag_settings`, verify column is dropped |
| Widget | `_showPalettePicker` rewrite | Minimal — palette picker widget test unchanged; integration test could verify `saveTagSettingProvider` is called |

---

## Sequencing (PR Order)

| Step | Changes | Test before commit? |
|------|---------|---------------------|
| 1 | Migration v9 code (data-fill only, no column drop yet) | ✅ |
| 2 | Reader providers switch to `tagSettingsMapProvider` | ✅ |
| 3 | Writer palette pickers switch to `saveTagSettingProvider` | ✅ |
| 4 | Remove dead `updateTagsColors` pipeline | ✅ dart analyze — unused imports |
| 5 | Remove `tagsColor` from table def, `_toCompanion`, `_fromDbEntry`, then drop column in v9 | ✅ |
| Final | `dart run build_runner build`, `dart analyze`, `flutter test` | ✅ |

---

## Open Questions

- [ ] None — all decisions resolved by exploration and codebase reading.
