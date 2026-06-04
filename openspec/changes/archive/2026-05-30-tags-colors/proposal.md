# Proposal: tags-colors

## Intent

Add per-entry tag color assignments so users can visually identify entries by color. Tags inherit a color from a 16-color palette; entries with multiple tags show a mixed color via HSL averaging.

## Scope

### In Scope
- Schema migration v5→v6: add `tags_color TEXT` column to `entries` table
- `Entry` domain model: new `Map<String, String> tagsColors` field (tag name → hex color)
- DAO serialization: encode/decode `tagsColors` as JSON alongside existing `tags`
- Color palette: 16 carefully chosen colors in a 4×4 grid (no full color picker)
- HSL color mixing: average hue, saturation, lightness when entry has multiple tags
- EntryCard grid: 4px left accent border colored by mixed tag color
- EntryCard list: colored dot next to title
- EntryDetailView body: accent bar on the body container
- Tag chips in filter row: colored background by tag's assigned color
- Tag chips in detail view: colored + long-press opens palette picker
- Palette picker widget: 4×4 grid of 16 color circles
- Color assignment: per-entry `{tagName: hex}` map

### Out of Scope
- Global tag registry or shared tag colors across entries
- Full HSV/HSL color picker
- Tag rename → stale color reconciliation (accepted edge case)
- Color export/import in backup format
- Color-based search or filtering

## Approach

Add `tags_color TEXT` column to `entries` via Drift migration (v5→v6). The `Entry` domain model gains `Map<String, String> tagsColors` alongside the existing `List<String> tags`. DAO serializes both as JSON columns. A new `TagPalette` constant defines 16 colors; `TagColorMixer` utility handles HSL averaging for multi-tag entries. UI widgets read the mixed color and apply the appropriate indicator (accent bar, dot, chip background). A new `PalettePicker` widget (4×4 grid) is triggered by long-press on tag chips in the detail view.

## Chained PR Plan

| # | Slice | Scope | Est. Δ |
|---|-------|-------|--------|
| 1 | **Foundation** | Schema migration v5→v6, `Entry.tagsColors` field, DAO encode/decode, `TagPalette` (16 colors), `TagColorMixer` (HSL avg), unit tests | ~250 |
| 2 | **Indicators** | EntryCard grid accent border, EntryCard list colored dot, EntryDetailView body accent bar, colored tag chips in filter row & detail view | ~200 |
| 3 | **Palette Picker** | `PalettePicker` widget (4×4 grid), long-press handler on detail tag chips, edit-flow integration (create/update propagate `tagsColors`), color assignment on selection | ~300 |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| FTS5 table not affected (tags FTS column stores only tag names, not colors) | Low | No changes to FTS5 schema; colors stored in separate column |
| Stale colors on tag rename — colors keyed by tag name, rename orphans the color entry | Low | Accepted edge case; user can reassign. Future global registry would solve this. |
| DAO `_fromMap` handles `null` `tags_color` for rows created before v6 | Low | `_fromMap` defaults to empty map on null/absent; existing entries gracefully show no color |
| HSL mixing produces unexpected colors when tags with very different hues combine | Medium | Averaging in HSL space produces muted/muddy results for divergent hues. Acceptable for indicator use; if unsatisfactory, can switch to "most frequent tag's color" later. |

## Rollback Plan

- **Database**: Migration is additive (new column, no dropped columns). Rollback: remove v6 migration step, schema version back to 5, drop `tags_color` column via ALTER TABLE.
- **Domain model**: Remove `tagsColors` field. No downstream code depends on it for core functionality.
- **UI**: Remove indicator widgets and palette picker. Tags return to uncolored state.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/domain/entities/entry.dart` | Modified | Add `@Default({}) Map<String, String> tagsColors` field |
| `lib/infrastructure/database/entries_table.dart` | Modified | Add `TextColumn get tagsColor` |
| `lib/infrastructure/database/app_database.dart` | Modified | Schema v5→v6 migration + add column step |
| `lib/infrastructure/database/entry_dao.dart` | Modified | Serialize/deserialize `tagsColors` |
| `lib/infrastructure/database/entry_repository_impl.dart` | Unchanged | Passes Entry through |
| `lib/domain/repositories/i_entry_repository.dart` | Unchanged | No API change |
| `lib/domain/usecases/create_entry.dart` | Modified | Accept `tagsColors` param |
| `lib/domain/usecases/update_entry.dart` | Modified | Accept/merge `tagsColors` |
| `lib/ui/widgets/entry_card.dart` | Modified | Add accent bar (grid) / colored dot (list) |
| `lib/ui/screens/entry_detail_view.dart` | Modified | Add body accent bar, colored chips, long-press → palette |
| `lib/ui/widgets/palette_picker.dart` | **New** | 4×4 grid palette picker widget |
| `lib/ui/providers/entry_providers.dart` | Unchanged | No new providers |
| New utilities | **New** | `TagPalette` constants, `TagColorMixer` HSL mixing |

## Dependencies

- **None**. Uses existing Drift, freezed, and Flutter Material. Column addition is a standard SQLite ALTER TABLE.

## Success Criteria

- `tags_color` column exists in SQLite after migration, default `null` for existing rows
- Entry model round-trips `tagsColors` through DAO → DB → DAO → Entry without data loss
- EntryCard grid shows 4px left accent border; list shows colored dot
- Tag chips in filter and detail views render with assigned color
- Long-press on detail tag chip opens 4×4 palette picker
- Selecting a color in the picker assigns it to that tag (per-entry) and persists on save
- Entries with multiple tags show a mixed color via HSL averaging
- All existing tests pass; new color utility tests cover HSL mixing and palette boundaries

## Next

Ready for **sdd-spec** (write delta specs) → **sdd-design** (detailed widget structure and provider architecture).
