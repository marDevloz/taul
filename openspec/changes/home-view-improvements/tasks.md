# Tasks: Home View Improvements

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 470 (350 + 120) |
| 400-line budget risk | Medium |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 → PR 2 |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Snake filter FABs replacing FilterChipsRow + TagFilterRow | PR 1 | ~350Δ, snake_fab.dart + filter_chips.dart + home_view.dart |
| 2 | Tag autocomplete + FAB transparency | PR 2 | ~120Δ, entry_detail_view.dart + quick-add FAB style in home_view.dart |

---

## PR 1 — Snake Filter FABs (~350Δ)

### Phase 1: Foundation

- [ ] 1.1 Create `lib/ui/widgets/snake_fab.dart` with `SnakeFab` StatefulWidget, stagger `AnimationController`, `SlideTransition` per item, `_FabItemPill` for individual filter pills
- [ ] 1.2 Modify `lib/ui/widgets/filter_chips.dart` — export `FilterTypePill` and `FilterTagPill` (remove `_` prefix) for reuse in SnakeFab items

### Phase 2: Home View Integration

- [ ] 2.1 Wire two `SnakeFab` instances in `lib/ui/screens/home_view.dart`: remove `FilterChipsRow`/`TagFilterRow` imports and usage, add `_expandedFabId` state for mutual exclusion, place TypeFilterFab + TagFilterFab + quick-add FAB in a Column
- [ ] 2.2 Wire `TypeFilterFab` with `selectedTypeFilterProvider` (5 items: "Todas" + 4 `EntryType` values), toggle off on re-select
- [ ] 2.3 Wire `TagFilterFab` with `selectedTagFilterProvider` + `tagsListProvider` (dynamic items, scrollable overflow)

### Phase 3: Testing

- [ ] 3.1 Test: TypeFilterFab expands 5 items with stagger, selection sets provider, re-select toggles off (Scenarios 1, 3)
- [ ] 3.2 Test: TagFilterFab shows dynamic tags, scrollable on overflow (Scenario 2)
- [ ] 3.3 Test: FAB mutual exclusion (only one expanded) + quick-add coexistence (Scenario 4)

---

## PR 2 — Tag Autocomplete + FAB Transparency (~120Δ)

### Phase 1: Autocomplete

- [x] 1.1 Replace tags `TextField` at `entry_detail_view.dart:310` with Material `Autocomplete<String>` using `tagsListProvider` as suggestion source; 300ms debounce, 1-char min, max 6 items
- [x] 1.2 Wire `onSelected` to append tag + ", " to controller; verify save still reads `tagsCtrl.text` at line 375 unchanged

### Phase 2: FAB Transparency + Testing

- [x] 2.1 Make quick-add `FloatingActionButton` at `home_view.dart:198` translucent (e.g. semi-transparent `backgroundColor` or wrapped in `Opacity`)
- [ ] 2.2 Test: autocomplete shows matching suggestions, no dropdown on no-match (Scenarios 5, 7, 8)
- [ ] 2.3 Test: selecting suggestion appends tag with comma+space (Scenario 6)
