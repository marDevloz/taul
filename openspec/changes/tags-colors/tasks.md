# Tasks: Tags with Colors

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~750 (250 + 200 + 300) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1: Foundation → PR 2: Indicators → PR 3: Palette Picker |
| Delivery strategy | force-chained |
| Chain strategy | **pending** |

```
Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High
```

### Suggested Work Units

| Unit | Goal | Likely PR | Base Branch | Notes |
|------|------|-----------|-------------|-------|
| 1 | Foundation — schema, model, palette, mixer, DAO, tests | PR 1 | main | Additive migration; no UI changes |
| 2 | Indicators — accent bars, colored chips, dots | PR 2 | main or PR 1 | Pure UI; no schema changes |
| 3 | Palette Picker — 4×4 grid, long-press, assignment flow | PR 3 | main or PR 2 | Depends on PR 1 for model; PR 2 for colored chips |

## Dependency Graph

```
T-01 (TagPalette) ──→ T-02 (TagColorMixer) ──→ T-07 (mixer tests)
                                                      
T-03 (Entry.tagsColors) ──→ T-06 (DAO encode/decode) ──→ T-08 (DAO tests)
                                                      │
T-04 (Drift table) ──→ T-05 (Schema migration) ──────┘
                                │
────────────────────────────────┼────────────────────────────────────────────
                                │               PR 2
                                ▼
T-09 (color_providers) ──→ T-10 (EntryCard grid)
                        ├──→ T-11 (EntryCard list dot)
                        ├──→ T-12 (DetailView accent bar) → T-14 (colored chips)
                        ├──→ T-13 (FilterRow chip color)
                        └──→ T-15 (use cases tagsColors) ─→ T-16 (widget tests)
                                │
────────────────────────────────┼────────────────────────────────────────────
                                │               PR 3
                                ▼
T-01 ──→ T-17 (PalettePicker widget) ──→ T-18 (long-press handler)
                                          └──→ T-19 (color assignment flow)
                                                 └──→ T-20 (persistence)
                                                        └──→ T-21 (provider invalidation)
                                                                 └──→ T-22 (widget tests)
```

## PR 1: Foundation (~250 lines)

- [ ] **T-01** Create `lib/shared/tag_palette.dart` — 16 `PaletteColor` constants with name, hex, `Color`, HSL values; `defaultGrey` constant
  - *Files*: `lib/shared/tag_palette.dart` (NEW)
  - *Depends*: none
  - *Accept*: all 16 entries have valid hex & HSL; `defaultGrey = #9E9E9E`
- [ ] **T-02** Create `lib/shared/tag_color_mixer.dart` — `TagColorMixer.mix()` using HSL circular-mean averaging; empty→grey, single→identity, multi→HSL avg
  - *Files*: `lib/shared/tag_color_mixer.dart` (NEW)
  - *Depends*: T-01
  - *Accept*: `mix([])` → grey, `mix([c])` → c, 3 colors → HSL avg, edge hues (0°/360°) wrap correctly
- [ ] **T-03** Add `@Default({}) Map<String, String> tagsColors` field to `Entry` freezed model
  - *Files*: `lib/domain/entities/entry.dart`
  - *Depends*: none
  - *Accept*: `Entry.fromJson`/`toJson` round-trips tagsColors; existing constructors still work with default `{}`
- [ ] **T-04** Add `TextColumn? get tagsColor => text().nullable()()` to `Entries` drift table
  - *Files*: `lib/infrastructure/database/entries_table.dart`
  - *Depends*: none
  - *Accept*: `tagsColor` column recognized by Drift codegen; nullable
- [ ] **T-05** Bump `schemaVersion` to 6, add `if (from < 6)` migration step calling `addColumn(entries, entries.tagsColor)`
  - *Files*: `lib/infrastructure/database/app_database.dart`
  - *Depends*: T-04
  - *Accept*: migration runs without error; existing rows get `tags_color = NULL`; FTS5 table unchanged
- [ ] **T-06** Update `EntryDao._toCompanion` to encode `tagsColors` as JSON (empty→null), `_fromMap` to decode (null→`{}`), `_fromDbEntry` to pass through `tagsColor`
  - *Files*: `lib/infrastructure/database/entry_dao.dart`
  - *Depends*: T-03, T-04
  - *Accept*: `insert` + `get` round-trips tagsColors; entry with empty tagsColors stores NULL
- [ ] **T-07** Write unit tests for `TagColorMixer.mix`: empty, single, 3 colors, 10 colors, circular hue edge (0° & 359°), saturation/lightness extremes
  - *Files*: `test/shared/tag_color_mixer_test.dart` (NEW)
  - *Depends*: T-02
  - *Accept*: all test cases pass; <1ms for ≤10 tags per NFR-03
- [ ] **T-08** Write unit tests for DAO round-trip: `tagsColors` with 3 entries, empty map, null legacy handling, exact map comparison after insert→read
  - *Files*: `test/infrastructure/database/entry_dao_test.dart` (NEW)
  - *Depends*: T-06
  - *Accept*: all round-trip tests pass; null column → `{}` per NFR-02

## PR 2: Indicators (~200 lines)

- [ ] **T-09** Create `lib/ui/providers/color_providers.dart` with `entryDisplayColorProvider` (pre-computes mixed `Color?`) and `tagColorProvider` (resolves per-tag `Color?` per entry)
  - *Files*: `lib/ui/providers/color_providers.dart` (NEW)
  - *Depends*: T-02, T-03
  - *Accept*: entry with 3 colored tags → mixed color; entry with uncolored tags → null; entry with no tags → null
- [ ] **T-10** Add 4px left accent border to EntryCard grid mode using `displayColor` parameter; transparent when null
  - *Files*: `lib/ui/widgets/entry_card.dart`
  - *Depends*: T-09
  - *Accept*: grid card shows 4px left border in mixed color; no indicator when null
- [ ] **T-11** Add 8px colored dot before title in EntryCard list mode using `displayColor`; hidden when null
  - *Files*: `lib/ui/widgets/entry_card.dart`
  - *Depends*: T-09
  - *Accept*: list card shows colored dot in `ListTile.leading` area; no dot when null
- [ ] **T-12** Wrap EntryDetailView body `SingleChildScrollView` in `Container` with left accent border using display color
  - *Files*: `lib/ui/screens/entry_detail_view.dart`
  - *Depends*: T-09
  - *Accept*: detail body has 4px left border in mixed color; transparent/grey fallback when null
- [ ] **T-13** Update `TagFilterRow._TagPill` to resolve tag color from visible entries and apply as `backgroundColor`
  - *Files*: `lib/ui/widgets/filter_chips.dart`
  - *Depends*: T-09
  - *Accept*: filter chip shows tag color when found in visible entries; default background when not found
- [ ] **T-14** Update `_NoteContent` and `_CredentialContent` tag `ActionChip`s in detail view to show colored background per tag
  - *Files*: `lib/ui/screens/entry_detail_view.dart`
  - *Depends*: T-09
  - *Accept*: each chip shows its assigned tag color as `backgroundColor`; no color when unassigned
- [ ] **T-15** Add optional `Map<String, String> tagsColors` param to `CreateEntry.call()` and `UpdateEntry.call()`
  - *Files*: `lib/domain/usecases/create_entry.dart`, `lib/domain/usecases/update_entry.dart`
  - *Depends*: T-03
  - *Accept*: calling without tagsColors uses default `{}`; existing callers continue working
- [ ] **T-16** Widget tests for EntryCard indicators: grid border renders with color, list dot renders with color, both absent when displayColor null
  - *Files*: `test/ui/widgets/entry_card_test.dart` (NEW)
  - *Depends*: T-10, T-11
  - *Accept*: all widget tests pass

## PR 3: Palette Picker (~300 lines)

- [ ] **T-17** Create `PalettePicker` `StatefulWidget` — 4×4 `GridView` of 48×48 circles, selected indicator (white checkmark + 2px border), wraps in `AlertDialog`
  - *Files*: `lib/ui/widgets/palette_picker.dart` (NEW)
  - *Depends*: T-01
  - *Accept*: renders 16 colored circles; selected circle shows checkmark overlay and border
- [ ] **T-18** Replace `onPressed` with `onLongPress` on detail tag `ActionChip`s to open `PalettePicker` dialog
  - *Files*: `lib/ui/screens/entry_detail_view.dart`
  - *Depends*: T-17, T-14
  - *Accept*: long-press on tag chip opens 4×4 palette dialog; short-tap still navigates to filter
- [ ] **T-19** Wire color selection: `PalettePicker` returns selected hex → update `entry.tagsColors` via `copyWith` → refresh UI
  - *Files*: `lib/ui/screens/entry_detail_view.dart`
  - *Depends*: T-18
  - *Accept*: selecting a color immediately updates chip background; entry model updated in memory
- [ ] **T-20** Save updated entry with new `tagsColors` via `UpdateEntry` usecase → DAO → SQLite persistence
  - *Files*: `lib/ui/screens/entry_detail_view.dart`
  - *Depends*: T-19, T-06
  - *Accept*: after save, color persists across app restart; stale colors handled gracefully
- [ ] **T-21** Invalidate `entryDetailProvider` and `entryDisplayColorProvider` after color assignment to re-render all indicators
  - *Files*: `lib/ui/providers/color_providers.dart`, `lib/ui/screens/entry_detail_view.dart`
  - *Depends*: T-20
  - *Accept*: grid card, list dot, and detail accent bar all update after color selection without manual refresh
- [ ] **T-22** Widget tests for `PalettePicker`: renders 16 items, selected circle shows checkmark, selection callback fires with correct hex
  - *Files*: `test/ui/widgets/palette_picker_test.dart` (NEW)
  - *Depends*: T-17
  - *Accept*: all widget tests pass

## Chain Strategy Recommendation

### Decision needed before apply: Yes

You need to choose a chain strategy:

1. **Stacked PRs to main** — each PR merges directly to `main` in order.
   - ✅ Fastest iteration, each PR is independently reviewable
   - ⚠️ PR 2 and PR 3 need PR 1 merged first (can start review in parallel)
   - Best for this feature since each PR produces a valid intermediate state

2. **Feature Branch Chain** — create a `feat/tags-colors` tracker branch; PR 1 targets it, PR 2 targets PR 1's branch, PR 3 targets PR 2's branch.
   - ✅ Single merge to main at the end, easy rollback
   - ⚠️ Higher branch management overhead, diffs include parent PR changes without rebase

**Recommendation**: Stacked PRs to main — each PR delivers a valid intermediate state (schema works without UI, indicators work without picker), and the team can review independently.

---

## Summary

| Phase | Tasks | Focus |
|-------|-------|-------|
| PR 1: Foundation | T-01 to T-08 | Model, schema, DAO, palette, mixer, unit tests |
| PR 2: Indicators | T-09 to T-16 | Color providers, accent bars, chips, widget tests |
| PR 3: Palette Picker | T-17 to T-22 | Picker widget, long-press, assignment flow, persistence |
| **Total** | **22 tasks** | |

**Implementation order**: Linear by PR — PR 1 must complete first (schema + model), then PR 2 (UI indicators), then PR 3 (picker interaction). Within each PR, follow task ID order.
