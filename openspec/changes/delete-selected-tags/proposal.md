# Proposal: Delete Selected Tags

## Intent

Batch-delete multiple tags from the tag management screen. Currently only single-tag delete via long-press → confirmation. Bulk delete reduces friction when cleaning up unused or duplicate tags.

## Scope

### In Scope
- Multi-select mode on `TagManagementScreen` (toggle via long-press)
- Action bar with delete icon visible when ≥1 tag selected
- Batch confirmation dialog with total tag + affected entry count
- Batch `DeleteTagSetting` + `removeTagFromEntries` per selected tag
- Provider invalidation cascade after batch
- System tags excluded from selection (per `system-tags` spec)
- SnackBar summary on completion

### Out of Scope
- Batch tag editing (rename, recolor)
- Undo / rollback
- Tag deletion from entry detail screen
- Selection persistence across screen revisits

## Capabilities

### New Capabilities
None — reuses existing paths, no new spec-level behavior.

### Modified Capabilities
- `system-tags`: Add batch delete prevention scenario (currently covers single-delete only)

## Approach

**Layer**: UI only (`tag_management_screen.dart`). No domain or infrastructure changes.

1. Selection state (`Set<String>`) local to widget — no Riverpod provider needed
2. Long-press user tag → enter selection mode
3. In selection mode: tap toggles selection, action bar replaces normal app bar
4. Trash → confirmation dialog listing tag + entry counts
5. Iterate selected, call `deleteUseCase(name)` + `removeTag(name)`, collect affected entry IDs
6. Invalidate `tagSettingsListProvider`, `entryListProvider`, per-entry providers
7. Exit selection, show SnackBar
8. System tags (`isSystem == true`) never selectable

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/ui/screens/tag_management_screen.dart` | **Modified** | Selection state, action bar, batch delete |
| `openspec/specs/system-tags/spec.md` | **Modified** | Add batch delete scenario |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| O(N·M) iterations for N tags × M entries | Low | Acceptable for typical <100 tags |
| System tags deletable in batch | Medium | Filter `isSystem` out of selection explicitly |
| Provider invalidation storm | Low | Collect entry IDs, deduplicate, invalidate once |

## Rollback Plan

Revert `tag_management_screen.dart` to HEAD. No migration or new persistence code — reuses existing single-delete paths.

## Dependencies

- `DeleteTagSetting` use case — existing
- `removeTagFromEntries` provider — existing
- `tagUsageCountProvider` — existing, for confirmation dialog

## Success Criteria

- [ ] Long-press → multi-select mode; tap toggles selection
- [ ] System tags never selectable in batch
- [ ] Action bar visible only when ≥1 tag selected
- [ ] Confirmation shows tag + entry count; confirm deletes + unlinks all, cancel exits cleanly
- [ ] Provider cascade invalidates correctly (tag list, entry list, per-entry)
- [ ] SnackBar shows summary on completion
- [ ] `dart analyze` passes with zero warnings
