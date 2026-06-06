# Proposal: Draft Entry Persistence

## Intent

Preserve in-progress entry content when `CreateEntrySheet` is dismissed (accidentally or intentionally) and restore it on reopen. Eliminate data loss from accidental sheet closure.

## Scope

### In Scope
- Save draft (title, Delta JSON content, tags, type) when sheet disposes
- Restore draft when sheet is created
- Clear draft on successful save
- Single draft slot: one in-progress entry at a time

### Out of Scope
- Periodic auto-save while typing (future)
- Quick-add sheet draft
- Drafts for edit-mode entries
- Server sync or multi-device draft sync

## Capabilities

### New Capabilities
- `entry-draft`: Draft storage for in-progress entry creation. Save/restore/clear lifecycle tied to CreateEntrySheet lifecycle.

### Modified Capabilities
None — pure new functionality, no existing spec changes.

## Approach

**Layer**: UI + new provider (no domain/infrastructure changes)

1. Create `lib/ui/providers/entry_draft_provider.dart`:
   - `EntryDraft` freezed model: `title`, `content` (Delta JSON), `tags` text, `manualType` (nullable)
   - `EntryDraftNotifier` (StateNotifier): `save()`, `restore()`, `clear()` methods
   - Persistence via `SharedPreferences` (single key `<EntryDraft>` with JSON)
   - Expose as Riverpod `StateNotifierProvider<EntryDraftNotifier, EntryDraft?>`

2. Modify `CreateEntrySheet`:
   - `initState`: read draft via provider → populate `_titleCtrl`, `_tagsCtrl`, `_richContent`, `_manualType`
   - `dispose`: save current state to draft
   - On successful save (`_save`): call `clear()` on draft provider
   - Guard: skip save if no content entered (empty title + empty content)

| Area | Impact | Description |
|------|--------|-------------|
| `lib/ui/providers/entry_draft_provider.dart` | **New** | Draft model + StateNotifier + provider |
| `lib/ui/screens/create_entry_sheet.dart` | **Modified** | Init/dispose hooks for draft lifecycle |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Stale draft on app crash before clear | Low | Single draft slot, overwritten on next write. No GC needed. |
| SharedPreferences sync delay | Low | Sync save — negligible latency for draft ops |
| Draft restored after app restart | Low (feature) | Intended — preserves across restarts. Clear on save. |

## Rollback Plan

Revert `create_entry_sheet.dart` changes and delete `entry_draft_provider.dart`. No migration needed — stray `SharedPreferences` keys are harmless.

## Dependencies

- `SharedPreferences` — already a project dependency
- `freezed` — already configured for codegen

## Success Criteria

- [ ] Writing in CreateEntrySheet, dismissing, and reopening restores title, content, tags, and type
- [ ] Successful save clears the draft (new sheet opens blank)
- [ ] Cancelling with empty fields creates no draft (no stale keys)
