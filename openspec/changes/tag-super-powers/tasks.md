# Tasks: Tag Super Powers

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 1580–1680 (all 5 PRs) |
| 400-line budget risk | Medium |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 → PR 2 → PR 3 → PR 4 → PR 5 |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: Low (PR 1–2), High (PR 3), Medium (PR 4–5)

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Copyable titles + detail styling | PR 1 | UI only, ~80 lines, no deps |
| 2 | Tag color ≠ version bump | PR 2 | New UC + DAO method, ~100 lines, no deps on PR 1 |
| 3 | Tag management CRUD + security | PR 3 | Foundation (table→DAO→UC) then UI; split if >400 |
| 4 | Inline expand entry cards | PR 4 | Depends on PR 3 for effective auth |
| 5 | Merge temporal | PR 5 | UI + domain, no deps on PR 3–4 |

PR 1 and PR 2 are independent (no ordering constraint). PR 3–5 are order-constrained.

---

## PR 1: Quick Wins (~80 lines)

### 1.1 Title copyable via long-press (`entry_detail_view.dart`)

- [ ] 1.1.1 Replace `Text(entry.title...)` with `SelectableText(entry.title...)` in `_NoteContent` and `_CredentialContent`, keeping same style parameters
- [ ] 1.1.2 Keep empty-title placeholder `(sin título)` as non-selectable `Text` — wrap with condition: `entry.title.isEmpty ? Text(...) : SelectableText(...)`
- [ ] 1.1.3 Write widget test: long-press shows native copy overlay when title is non-empty; empty title shows non-selectable placeholder

### 1.2 Detail accent bar matches EntryCard style (`entry_detail_view.dart`, `color_providers.dart`)

- [ ] 1.2.1 Widen accent bar from 4px to 8px in `EntryDetailView.build` `Container(width: 4 → 8)`
- [ ] 1.2.2 Apply displayColor background tint (8% opacity) behind the body using existing `displayColor` — add tinted `ColoredBox` as `Positioned.fill` child inside the content `Row`
- [ ] 1.2.3 Guard tint & accent: render only when `displayColor != null` (no-tag entries have no bar/tint)
- [ ] 1.2.4 Write widget test: entry with tag color shows 8px accent bar + tint; entry with no tags shows neither

---

## PR 2: Version Separation (~100 lines)

### 2.1 New DAO method `updateTagsColors` (`entry_dao.dart`)

- [ ] 2.1.1 Add `Future<void> updateTagsColors(String id, Map<String, String> tagsColors)` to `EntryDao` — writes only `tagsColor` column via targeted UPDATE, no other columns touched
- [ ] 2.1.2 Write DAO test: create entry, call `updateTagsColors`, verify `version` and `updatedAt` unchanged

### 2.2 New repo interface method (`i_entry_repository.dart`)

- [ ] 2.2.1 Add `Future<void> updateTagsColors(String id, Map<String, String> tagsColors)` to `IEntryRepository`

### 2.3 Repo impl delegates to DAO (`entry_repository_impl.dart`)

- [ ] 2.3.1 Implement `updateTagsColors` in `EntryRepositoryImpl` — delegates to `_dao.updateTagsColors(id, tagsColors)`

### 2.4 New use case `UpdateEntryTagsColors` (new file `update_entry_tags_colors.dart`)

- [ ] 2.4.1 Create `lib/domain/usecases/update_entry_tags_colors.dart` — single `call(Entry entry, Map<String, String> tagsColors)` that copies entry with new `tagsColors` and calls `repository.updateTagsColors(entry.id, tagsColors)`
- [ ] 2.4.2 Unit test: mock `IEntryRepository`, call UC, verify `updateTagsColors` called with correct args, **no** `update` call

### 2.5 Refactor palette picker handlers to use new UC (`entry_detail_view.dart`)

- [ ] 2.5.1 Replace `ref.read(updateEntryProvider).call(entry, tagsColors: newTagsColors)` with `ref.read(updateEntryTagsColorsProvider).call(entry, newTagsColors)` in both `_NoteContent._showPalettePicker` and `_CredentialContentState._showPalettePicker`
- [ ] 2.5.2 Keep propagation loop that iterates all entries sharing the same tag — also switch those `updateEntry` calls to the new UC
- [ ] 2.5.3 Register `updateEntryTagsColorsProvider` in entry_providers.dart as `Provider` wrapping the UC

### 2.6 Write integration test

- [ ] 2.6.1 End-to-end: create entry via DAO, call UC via real repo, read entry back, assert version/updatedAt unchanged

---

## PR 3: Tag Management (~600–800 lines — split into two sub-PRs)

### PR 3a: Foundation (table + DAO + UC + migration) (~350 lines)

- [ ] 3a.1 Create `lib/infrastructure/database/tag_settings_table.dart` — Drift `TagSettings` table (name PK, color nullable, isSecure default false, createdAt)
- [ ] 3a.2 Register table in `app_database.dart` — add to `@DriftDatabase(tables: [...])` list
- [ ] 3a.3 Add v6→v7 migration in `onUpgrade`: CREATE TABLE, scan entries for unique {tag→color}, INSERT into tag_settings
- [ ] 3a.4 Create `TagSettingsDao` — getAll, getByName, upsert, delete with in-memory Drift tests
- [ ] 3a.5 Create `ITagSettingsRepository` interface + `TagSettingsRepositoryImpl`
- [ ] 3a.6 Create use cases: `GetTagSettings`, `SaveTagSetting`, `DeleteTagSetting` with mock tests
- [ ] 3a.7 Migration test: create DB at v6 with entries having tags+colors, upgrade to v7, verify tag_settings populated

### PR 3b: UI + providers (~400 lines)

- [ ] 3b.1 Create `tag_settings_providers.dart` — providers for list, upsert, delete; `tagSettingsMapProvider` (name→TagSetting)
- [ ] 3b.2 Modify `color_providers.dart` — `tagColorMapProvider` reads from tag_settings as fallback/override, not only entry-scoped
- [ ] 3b.3 Create `effective_auth_provider.dart` — `Provider.family<bool, String>` that computes `requiresAuth || any tag in tag_settings.is_secure`
- [ ] 3b.4 Add tag management section to `settings_screen.dart` — ListTile "Gestionar etiquetas" that navigates to tag management screen
- [ ] 3b.5 Create `tag_management_screen.dart` — ListView of all tags, each with rename dialog, delete confirm, secure toggle (uses requireMasterKey for sec toggle)
- [ ] 3b.6 Wire `entry_providers.dart` — add tag settings providers so entry detail shows canonical colors
- [ ] 3b.7 Write widget tests for tag management CRUD dialogs and secure toggle

---

## PR 4: Inline Expand (~300 lines)

### 4.1 Content display widgets (`entry_expanded_content.dart`)

- [ ] 4.1.1 Extract `_NoteContent` body into reusable `EntryExpandedContent` widget — shows content + tag chips
- [ ] 4.1.2 Handle credential type: show locked state with "Requires master password" instead of content when entry is secure

### 4.2 EntryCard expandable mode (`entry_card.dart`)

- [ ] 4.2.1 Add `isExpanded` and `onToggle` params to `EntryCard`
- [ ] 4.2.2 Single tap → toggle expand (collapse previous via parent state); double tap → navigate to detail
- [ ] 4.2.3 Animate expand/collapse <200ms via `AnimatedCrossFade` or `AnimatedSize`
- [ ] 4.2.4 Wire `effectiveAuthProvider` — if entry requires auth or any tag is secure, show lock icon and skip expand on tap (double-tap only)

### 4.3 HomeView integration (`home_view.dart`)

- [ ] 4.3.1 Add `_expandedEntryId` state to HomeView — tracks which card is expanded, collapses on new tap
- [ ] 4.3.2 Pass `isExpanded` and `onToggle` to each `EntryCard`
- [ ] 4.3.3 Write widget tests: tap expands, tap another collapses previous, double-tap opens detail, secure shows lock

---

## PR 5: Merge Temporal (~400 lines)

### 5.1 Multi-select mode (`home_view.dart`)

- [ ] 5.1.1 Add `_selectedEntryIds` set + `isSelectMode` bool state
- [ ] 5.1.2 Long-press on EntryCard enters select mode, toggles that entry
- [ ] 5.1.3 AppBar shows selected count + "Merge" button (enabled when ≥2 selected) + "Cancel" to exit select mode
- [ ] 5.1.4 Render selected state visually (checkmark overlay or tinted card)

### 5.2 Merge service (`merge_service.dart`)

- [ ] 5.2.1 Create `MergeService.concatenate(List<Entry>)` — returns string `-- {title} --\n\n{content}\n\n` per entry
- [ ] 5.2.2 Enforce 20-entry max — throw or return error if >20
- [ ] 5.2.3 Unit test: 2 entries, 1 entry, empty content, >20 entries rejected

### 5.3 Merge editor screen (`merge_editor_screen.dart`)

- [ ] 5.3.1 Create full-screen editor pre-filled with merged text — plain `TextField` with monospace font
- [ ] 5.3.2 "Save as new note" button calls `CreateEntry` with type=note, title="Merge YYYY-MM-DD", content=edited text
- [ ] 5.3.3 Originals untouched — no delete, no update on source entries
- [ ] 5.3.4 Wire into HomeView — "Merge" app bar action navigates to merge editor with selected entries
- [ ] 5.3.5 Widget test: merge editor shows concatenated text, save creates entry, originals unchanged

---

## Testing Summary

| Phase | Tests | Type |
|-------|-------|------|
| PR 1 – SelectableText | Widget: long-press copy overlay | widget |
| PR 1 – Accent + tint | Widget: display color bar/tint present/absent | widget |
| PR 2 – DAO | Unit: updateTagsColors preserves version | unit |
| PR 2 – UseCase | Unit: calls updateTagsColors, not update | unit |
| PR 2 – Integration | E2E: real DB + UC, version unchanged | integration |
| PR 3 – DAO | Unit: round-trip CRUD on TagSettings | unit |
| PR 3 – Migration | Integration: v6→v7 populates tag_settings | integration |
| PR 3 – UI | Widget: tag CRUD dialogs, secure toggle | widget |
| PR 4 – Expand | Widget: tap/double-tap/lock behavior | widget |
| PR 5 – MergeService | Unit: concatenation format, max-20 | unit |
| PR 5 – Editor | Widget: merge + save | widget |
