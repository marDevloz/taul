# Proposal: TagSettings Single Source of Truth for Tag Colors

## Intent

Eliminate `entries.tags_color` as a parallel color source. Tag colors are stored both per-entry (JSON map) and per-tag (`tag_settings.color`) with no cross-sync. Two palette picker copies write to different sources, and the N-entry propagation loop is wasteful. Make `tag_settings.color` the single authoritative source.

## Scope

### In Scope
- Rewrite `entryDisplayColorProvider` and `tagColorForEntryProvider` to read from `tagSettingsMapProvider`
- Rewrite both `_showPalettePicker` copies to write to `tag_settings` instead of per-entry `tags_color`
- One-time data-fill: scan existing `entries.tags_color`, deduplicate by tag name, write to `tag_settings.color` where null
- Remove `UpdateEntryTagsColors` use case, repo method, DAO method, `updateEntryTagsColorsProvider`
- Add migration v9 to drop `entries.tags_color` column

### Out of Scope
- User-facing color behavior changes
- System tag defaults or palette changes
- Tag management screen UI changes

## Capabilities

Pure refactor — no spec-level behavior changes. The `system-tags` spec already defines correct color-per-tag semantics.

### New Capabilities
None

### Modified Capabilities
None

## Approach

**Direct switch** — atomic change, no dual-write bridge:

1. **Data-fill** — populate `tag_settings.color` from `entries.tags_color` before switching
2. **Readers** — `entryDisplayColorProvider` and `tagColorForEntryProvider` switch to `tagSettingsMapProvider`
3. **Writers** — both `_showPalettePicker` write to `tag_settings` via `saveTagSettingProvider`
4. **Cleanup** — remove `UpdateEntryTagsColors` pipeline and `updateEntryTagsColorsProvider`
5. **Migration v9** — drop `entries.tags_color` column

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `domain/usecases/update_entry_tags_colors.dart` | Removed | Delete file |
| `domain/repositories/i_entry_repository.dart` | Modified | Remove `updateTagsColors` |
| `infrastructure/database/entry_dao.dart` | Modified | Remove method, simplify map helpers |
| `infrastructure/database/entry_repository_impl.dart` | Modified | Remove delegation |
| `infrastructure/database/entries_table.dart` | Modified | Drop `tagsColor` (migration v9) |
| `infrastructure/database/app_database.dart` | Modified | Add migration v9 |
| `ui/providers/color_providers.dart` | Modified | Switch readers to `tagSettingsMapProvider` |
| `ui/providers/entry_providers.dart` | Modified | Remove `updateEntryTagsColorsProvider` |
| `ui/screens/entry_detail_view.dart` | Modified | Rewrite both palette pickers |
| `test/` | New | Color provider unit tests |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Color data loss from unsynced entries | Low | Data-fill migration before switch |
| `tag_settings.color` null for some tags | Low | Data-fill sets them from `entries.tags_color` |
| System tag color resets | Low | `TagPalette.systemTagDefaults` fallback |

## Rollback Plan

Revert the PR. Downgrade migration v9 if already applied (re-add `tags_color` column, restore old providers and writers).

## Dependencies

None.

## Success Criteria

- [ ] All existing tag colors display identically before and after
- [ ] Changing a tag color in entry detail updates all entries immediately (no propagation loop)
- [ ] Changing a tag color in tag management works identically
- [ ] `entries.tags_color` column removed in schema v9
- [ ] `dart analyze` clean, all tests pass
