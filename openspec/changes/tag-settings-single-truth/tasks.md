# Tasks: TagSettings Single Source of Truth for Tag Colors

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | **~310** (130 add + 180 delete across 14 files) |
| 400-line budget risk | **Medium** |
| Chained PRs recommended | **Yes** (forced by orchestrator) |
| Suggested split | PR 1 → PR 2 → PR 3 |
| Delivery strategy | `force-chained` |
| Chain strategy | `stacked-to-main` |

```
Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: Medium
```

### Context: stacked-to-main with DB migrations

DB schema changes are the hardest to chain. The solution: **v9 = data-fill only** (PR 1), **v10 = column drop** (PR 3). Between them the column sits unused in the DB but still present in the drift table definition — zero schema mismatch.

### Suggested Work Units

| Unit | Goal | PR | Base | Est. Lines |
|------|------|----|------|------------|
| 1 | v9 data-fill migration + reader providers + tests | PR 1 | main | ~100 |
| 2 | Writer palette pickers switch to `saveTagSettingProvider` | PR 2 | main | ~80 |
| 3 | v10 column drop + schema cleanup + dead code + build_runner | PR 3 | main | ~130 |

---

## PR 1 — v9 Data-fill Migration + Reader Providers

### Phase 1.1: Infrastructure — v9 Data-fill Migration

- [ ] 1.1.1 Bump `schemaVersion` from 8 to 9 in `app_database.dart`
- [ ] 1.1.2 Add `onUpgrade` block for `from < 9`: scan `entries.tags_color`, deduplicate by tag name, write to `tag_settings.color` where null. Use drift typed queries (column still present in table def).
- [ ] 1.1.3 [TEST RED] Write migration v9 test: `AppDatabase.custom()` with schema v8 → insert entries with `tags_color` → migrate to v9 → verify data in `tag_settings` matches deduplicated expected values → verify v9 runs idempotently
- [ ] 1.1.4 `flutter test` — migration test passes

### Phase 1.2: UI — Reader Providers Switch

- [ ] 1.2.1 [TEST RED] Write unit test for `entryDisplayColorProvider`: mock `entryDetailProvider` (entry with tags) + `tagSettingsMapProvider` (tag→color map). Verify mix color output for: 0 tags → null, N tags with colors → `TagColorMixer.mix` result, tags without colors → `TagPalette.defaultGrey`
- [ ] 1.2.2 [TEST RED] Write unit test for `tagColorForEntryProvider`: mock `tagSettingsMapProvider`. Verify resolved color for matching tag → `Color`, unknown tag → null
- [ ] 1.2.3 Switch `entryDisplayColorProvider` in `color_providers.dart`: add `ref.watch(tagSettingsMapProvider)`, replace `entry.tagsColors[t]` with `tagMap[t.toLowerCase()]?.color`
- [ ] 1.2.4 Switch `tagColorForEntryProvider` in `color_providers.dart`: add `ref.watch(tagSettingsMapProvider)`, replace `entry.tagsColors[tag]` with `tagMap[tag.toLowerCase()]?.color`. Drop unused `entryId` param internally (keep signature for call-site compat).
- [ ] 1.2.5 `flutter test` — new unit tests pass, no regressions

### PR 1 Verification

- [ ] V1.1 `dart analyze` — zero warnings
- [ ] V1.2 `flutter test` — all tests pass

---

## PR 2 — Writer Palette Pickers

### Phase 2.1: UI — Rewrite _NoteContent._showPalettePicker

- [ ] 2.1.1 Read initial color from `tagSettingsMapProvider` instead of `entry.tagsColors[tagName]`: `final tagMap = ref.watch(tagSettingsMapProvider); final currentHex = tagMap[tagName.toLowerCase()]?.color`
- [ ] 2.1.2 Replace `updateEntryTagsColorsProvider` call + propagation loop: call `ref.read(saveTagSettingProvider).call(TagSetting(name: tagName, color: selectedHexOrNull))` **once**
- [ ] 2.1.3 System tag "sin color" revert: write `TagPalette.systemTagDefaults[name]` to `tag_settings.color` instead of per-entry map
- [ ] 2.1.4 Replace invalidation block: `ref.invalidate(tagSettingsListProvider)` (cascade handles the rest). Remove `entryListProvider`, `entryDetailProvider`, `entryDisplayColorProvider`, `tagColorMapProvider` invalidations.

### Phase 2.2: UI — Rewrite _CredentialContent._showPalettePicker

- [ ] 2.2.1 Same changes as 2.1.1–2.1.4 applied to the second `_showPalettePicker` copy (line 1132)

### PR 2 Verification

- [ ] V2.1 `dart analyze` — zero warnings
- [ ] V2.2 `flutter test` — no regression in entry detail widget tests

---

## PR 3 — Column Drop + Schema Cleanup + Dead Code + Build

### Phase 3.1: Infrastructure — v10 Column Drop Migration

- [ ] 3.1.1 Bump `schemaVersion` from 9 to 10 in `app_database.dart`
- [ ] 3.1.2 Add `onUpgrade` block for `from < 10`: `ALTER TABLE entries DROP COLUMN tags_color`
- [ ] 3.1.3 [TEST RED] Write migration v10 test: schema v9 with `tags_color` column → migrate to v10 → verify `tags_color` column no longer exists in table info
- [ ] 3.1.4 `flutter test` — migration tests passes

### Phase 3.2: Infrastructure — Drift Schema Cleanup

- [ ] 3.2.1 Remove `tagsColor` column getter from `entries_table.dart`
- [ ] 3.2.2 Remove `tagsColor` from `_toCompanion` in `entry_dao.dart` (line 137–139)
- [ ] 3.2.3 Remove `'tags_color'` line from `_fromDbEntry` in `entry_dao.dart` (line 161)
- [ ] 3.2.4 Remove tagsColors round-trip test group in `entry_dao_test.dart` (lines 25–137) — tests reference removed column and `updateTagsColors` method

### Phase 3.3: Domain + Infrastructure — Remove `updateTagsColors` Pipeline

- [ ] 3.3.1 Delete `lib/domain/usecases/update_entry_tags_colors.dart`
- [ ] 3.3.2 Remove `updateTagsColors` method from `i_entry_repository.dart` (line 14)
- [ ] 3.3.3 Remove `updateTagsColors` method from `entry_repository_impl.dart` (lines 46–48)
- [ ] 3.3.4 Remove `updateTagsColors` method from `entry_dao.dart` (lines 34–40)
- [ ] 3.3.5 Remove `updateEntryTagsColorsProvider` + import from `entry_providers.dart` (lines 18, 158–160)

### Phase 3.4: Final Build + Verification

- [ ] 3.4.1 `dart run build_runner build` — clean drift codegen without `tagsColor`
- [ ] 3.4.2 `dart analyze` — zero warnings (no unused imports, no dead references)
- [ ] 3.4.3 `flutter test` — all tests pass (migration tests + refactored provider tests)

---

## Summary

| PR | Focus | Files | Est. ± Lines | Risk |
|----|-------|-------|-------------|------|
| 1 | v9 data-fill + reader providers + tests | 4 | +100 | Low |
| 2 | Writer palette pickers switch | 1 | +80 | Low |
| 3 | v10 column drop + schema cleanup + dead code + build | 9 | -130 net | Medium (drops column) |
| **Total** | | **14** | **~310** | |
