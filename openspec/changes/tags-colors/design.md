# Design: Tags with Colors

## Technical Approach

Add a `tags_color TEXT` column to the `entries` table via Drift schema migration v5→v6, storing a JSON map of `{tagName: "#RRGGBB"}`. The `Entry` domain model gains `Map<String, String> tagsColors`. A new `TagColorMixer` utility computes a single display color via HSL averaging for multi-tag entries. UI widgets (`EntryCard`, `EntryDetailView`, `TagFilterRow`) consume the pre-computed display color for accent indicators. A `PalettePicker` widget (4×4 grid of 16 colors) is triggered by long-press on detail tag chips.

## Architecture Decisions

| Decision | Option | Trade-off | Choice |
|----------|--------|-----------|--------|
| Color storage | (a) Per-entry JSON map in new column, (b) new `entry_tags` join table with color column | (a) simpler, no schema complexity, no global registry; (b) normalized, supports shared colors, but requires join queries and migration of existing tag storage | **(a)** Per-entry JSON map in `tags_color` TEXT column. Simpler, matches existing `tags` storage pattern, no join overhead. Stale colors on tag rename accepted as minor edge case. |
| Color resolution approach | (a) Pre-compute in providers, (b) compute on-the-fly in widgets | (a) cleaner separation, testable, reactive; (b) simpler but mixes logic in widgets | **(a)** Pre-compute display color in a new Riverpod provider. Widgets receive `Color?` and render. |
| Palette picker approach | (a) Simple `showDialog` with GridView, (b) overlay widget | (a) standard pattern, fewer lifecycle issues; (b) more flexible positioning | **(a)** `showDialog<Color>` with embedded `PalettePicker`. Standard Material pattern. |
| Palette picker widget type | (a) `StatelessWidget`, (b) `StatefulWidget` | (a) simpler, no local state; (b) needed only if tracking "selected" internally | **(b)** `StatefulWidget` — needs to track the currently-selected color for visual indicator when dialog is already open. |

## Data Flow

```
User action (long-press tag chip)
    │
    ▼
EntryDetailView → showDialog(PalettePicker)
    │                       │
    │         User selects color
    │                       │
    │              ◄────────┘
    ▼
ref.read(entryDetailProvider.notifier) → copyWith(tagsColors)
    │
    ▼
UpdateEntry usecase → EntryRepositoryImpl → EntryDao.update
    │
    ▼
SQLite: tags_color column updated
    │
    ▼
Provider invalidation → EntryCard/DetailView rebuild → TagColorMixer.mix() → display Color
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/domain/entities/entry.dart` | Modify | Add `@Default({}) Map<String, String> tagsColors` field |
| `lib/infrastructure/database/entries_table.dart` | Modify | Add `TextColumn? get tagsColor` (nullable) |
| `lib/infrastructure/database/app_database.dart` | Modify | Schema version 6, migration step `from < 6` |
| `lib/infrastructure/database/entry_dao.dart` | Modify | `_toCompanion` encode, `_fromMap` decode, `_fromDbEntry` passthrough |
| `lib/shared/tag_palette.dart` | **New** | 16-color constants with hex + HSL |
| `lib/shared/tag_color_mixer.dart` | **New** | HSL averaging utility class |
| `lib/ui/widgets/palette_picker.dart` | **New** | 4×4 grid palette picker dialog |
| `lib/ui/widgets/entry_card.dart` | Modify | Accept `Color? displayColor`, add border/dot |
| `lib/ui/screens/entry_detail_view.dart` | Modify | Accent bar, colored chip backgrounds, long-press → picker |
| `lib/ui/widgets/filter_chips.dart` | Modify | `_TagPill` accepts enforced color per tag |
| `lib/domain/usecases/create_entry.dart` | Modify | Accept optional `Map<String, String>? tagsColors` |
| `lib/domain/usecases/update_entry.dart` | Modify | Accept optional `Map<String, String>? tagsColors` |
| `lib/ui/providers/color_providers.dart` | **New** | `entryDisplayColorProvider`, `tagColorMapProvider` |
| `test/shared/tag_color_mixer_test.dart` | **New** | Unit tests for HSL mixing |
| `test/ui/widgets/palette_picker_test.dart` | **New** | Widget tests for palette |
| `test/infrastructure/database/entry_dao_test.dart` | **New** | DAO round-trip tests for tagsColors |

## Interfaces / Contracts

### TagPalette Constants (`lib/shared/tag_palette.dart`)

```dart
class TagPalette {
  const TagPalette._();

  static const List<PaletteColor> colors = [...];

  static const Color defaultGrey = Color(0xFF9E9E9E);
}

class PaletteColor {
  final String name;
  final Color color;           // Flutter Color from hex
  final String hex;            // "#RRGGBB"
  final double hue;            // 0-360
  final double saturation;     // 0-1
  final double lightness;      // 0-1

  const PaletteColor({
    required this.name,
    required this.color,
    required this.hex,
    required this.hue,
    required this.saturation,
    required this.lightness,
  });
}
```

### TagColorMixer (`lib/shared/tag_color_mixer.dart`)

```dart
class TagColorMixer {
  const TagColorMixer._();

  /// Mixes [colors] into a single color using HSL circular-mean averaging.
  /// - Empty list → [TagPalette.defaultGrey]
  /// - Single color → returns that color
  static Color mix(List<Color> colors);
}
```

Algorithm:
1. If `colors.isEmpty` → return `TagPalette.defaultGrey`
2. If `colors.length == 1` → return `colors[0]`
3. Convert each `Color` to HSL via `ColorUtils` (or `HSLColor` from Flutter)
4. Compute circular mean of hues: convert each hue to radians (θ = hue * π / 180), average sin(θ) and cos(θ), `avgHue = atan2(avgSin, avgCos) * 180 / π`, normalize to 0-360
5. Average saturation and lightness
6. Convert back to `Color` via `HSLColor.fromAHSL(1.0, avgHue, avgSat, avgLight).toColor()`

### Entry domain model change (`lib/domain/entities/entry.dart`)

```dart
@freezed
class Entry with _$Entry {
  const Entry._();
  const factory Entry({
    // ... existing fields unchanged ...
    @Default([]) List<String> tags,
    @Default({}) Map<String, String> tagsColors,
    // ...
  }) = _Entry;
}
```

### Drift table change (`lib/infrastructure/database/entries_table.dart`)

```dart
class Entries extends Table {
  // ... existing columns unchanged ...
  TextColumn get tags => text()();
  TextColumn? get tagsColor => text().nullable()();  // NEW
  // ...
}
```

### DAO changes (`lib/infrastructure/database/entry_dao.dart`)

**`_toCompanion`** — add `tagsColor`:
```dart
tagsColor: entry.tagsColors.isEmpty
    ? const Value(null)
    : Value(jsonEncode(entry.tagsColors)),
```

**`_fromMap`** — add decode:
```dart
final tagsColorsRaw = _val<String>(data, 'tagsColors', 'tags_color');
// ...
tagsColors: tagsColorsRaw != null
    ? Map<String, String>.from(jsonDecode(tagsColorsRaw) as Map)
    : {},
```

**`_fromDbEntry`** — passthrough `row.tagsColor`:
```dart
'tags_color': row.tagsColor,
```

### Schema migration (`lib/infrastructure/database/app_database.dart`)

```dart
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    // ...
    onUpgrade: (m, from, to) async {
      // ... existing <2, <3, <4, <5 blocks unchanged ...
      if (from < 6) {
        await m.addColumn(entries, entries.tagsColor);
      }
    },
    // ...
  );
}
```

SQL generated by Drift: `ALTER TABLE entries ADD COLUMN tags_color TEXT`

**FTS5**: No changes needed. The FTS5 `tags` column already indexes only `entry.tags.join(' ')` — colors are in the separate `tags_color` column and not fed into FTS.

### New providers (`lib/ui/providers/color_providers.dart`)

```dart
/// Pre-computes the mixed display color for an entry.
/// Returns null if entry has no tags or no color assignments.
final entryDisplayColorProvider = Provider.autoDispose.family<Color?, String>((ref, entryId) {
  final entry = ref.watch(entryDetailProvider(entryId)).valueOrNull;
  if (entry == null || entry.tags.isEmpty) return null;
  final matched = entry.tags
      .map((t) => entry.tagsColors[t])
      .whereType<String>()
      .map((hex) => Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000))
      .toList();
  if (matched.isEmpty) return null;
  return TagColorMixer.mix(matched);
});

/// Resolves the color for a specific tag from an entry's tagsColors.
/// Returns null if tag has no color assigned in that entry.
final tagColorProvider = Provider.autoDispose.family<Color?, ({String entryId, String tag})>(
  (ref, params) {
    final entry = ref.watch(entryDetailProvider(params.entryId)).valueOrNull;
    if (entry == null) return null;
    final hex = entry.tagsColors[params.tag];
    if (hex == null) return null;
    return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
  },
);
```

### PalettePicker (`lib/ui/widgets/palette_picker.dart`)

```dart
class PalettePicker extends StatefulWidget {
  final Color? initialColor;
  final ValueChanged<String> onColorSelected;  // hex string

  const PalettePicker({
    super.key,
    this.initialColor,
    required this.onColorSelected,
  });
}
```

Layout: 4×4 `GridView` with 48×48 `Container` circles. Selected color shows a white checkmark icon overlay and a 2px border. Wrapped in `AlertDialog` when used from EntryDetailView.

### EntryCard changes (`lib/ui/widgets/entry_card.dart`)

Accept new optional param:
```dart
final Color? displayColor;  // pre-computed mixed color, null = no indicator
```

- **Grid mode**: Wrap existing `Card` with a `Container` that has `BoxDecoration(border: Border(left: BorderSide(color: displayColor ?? Colors.transparent, width: 4)))`.
- **List mode**: Add a `Container(width: 8, height: 8, decoration: BoxDecoration(color: displayColor, shape: BoxShape.circle))` before the title in the `ListTile.leading` area.

### EntryDetailView changes

- **Accent bar**: Wrap body `SingleChildScrollView` in a `Container` with same left-border approach.
- **Colored chips**: ActionChip background color from `tagColorProvider` for the current entry+tag. Use `Chip`'s `backgroundColor` property.
- **Long-press**: Replace `onPressed` with `onLongPress` on tag chips that opens:
  ```dart
  final color = await showDialog<Color>(
    context: context,
    builder: (_) => PalettePickerDialog(
      initialColor: TagPalette.colors.firstWhereOrNull(
        (c) => c.hex == entry.tagsColors[t],
      )?.color,
    ),
  );
  if (color != null) { /* update entry.tagsColors via copyWith */ }
  ```

### TagFilterRow changes

`_TagPill` already accepts `Color? color`. Problem: colors are per-entry, but filter row shows global tags. For now: `TagFilterRow` resolves best-effort by scanning all visible entries for the tag's color. Implementation:

```dart
// In _TagPill resolution within TagFilterRow build:
Color? _resolveTagColor(String tag, List<Entry> entries) {
  for (final e in entries) {
    final hex = e.tagsColors[tag];
    if (hex != null) {
      return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
    }
  }
  return null;
}
```

### Use case changes

**CreateEntry** — add optional param:
```dart
Future<Entry> call({
  // ... existing params ...
  List<String> tags = const [],
  Map<String, String> tagsColors = const {},
  // ...
}) async {
  final entry = Entry(
    // ...
    tags: tags,
    tagsColors: tagsColors,
    // ...
  );
```

**UpdateEntry** — add optional param:
```dart
Future<Entry> call(
  Entry existing, {
  // ... existing params ...
  List<String>? tags,
  Map<String, String>? tagsColors,
  // ...
}) async {
  final updated = existing.copyWith(
    // ...
    tags: tags ?? existing.tags,
    tagsColors: tagsColors ?? existing.tagsColors,
    // ...
  );
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `TagColorMixer.mix` — empty, single, 3 colors, circular hue edge (0° & 360°) | Pure function tests, no mocks |
| Unit | `PaletteColor` constants — all 16 have valid hex, valid HSL | Verify each entry |
| Integration | DAO round-trip: encode → store → read → decode matches original | `AppDatabase.forTesting()` |
| Integration | Legacy null handling: DB row with `tags_color = NULL` → empty map | Raw insert, then read via DAO |
| Integration | Empty map round-trip: `tagsColors = {}` → stored as NULL | Verify column is NULL |
| Widget | `PalettePicker` renders 16 colored circles | `find.byType(Container)` count |
| Widget | EntryCard with/without displayColor | Verify border/dot presence |

## Migration / Rollout

- **Migration**: Additive column (`ALTER TABLE entries ADD COLUMN tags_color TEXT`). Existing rows get `NULL`. No data loss.
- **Rollback**: Revert `schemaVersion` to 5, remove the `< 6` migration step, drop column via `ALTER TABLE entries DROP COLUMN tags_color`, revert domain model and DAO.

## Open Questions

- None. All technical decisions are resolved by the spec and proposal.

## Next Step

Ready for **sdd-tasks** (break into implementation tasks).
