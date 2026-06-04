# Delta Specs: Tag Super Powers

## Overview

Five deltas: modified `entry-detail` and `tags-colors`, new `tag-management`, `inline-expand`, `merge-temporal`.

---

## PR 1 — Copyable Titles + Detail Styling

**Domain**: `entry-detail` (modified)

### ADDED Requirements

#### Title MUST be copyable via long-press

EntryDetailView title SHALL use `SelectableText`. Same layout, no visual change.

- **GIVEN** entry "Meeting Notes" in detail view
- **WHEN** user long-presses title
- **THEN** native copy overlay appears
- **GIVEN** entry with empty title
- **WHEN** detail view renders
- **THEN** placeholder "(sin título)" is non-selectable Text

#### Detail view MUST render accent bar + background tint

Body SHALL show 8px left accent bar in `displayColor` and full-background tint at 8% opacity. Matches EntryCard list style.

- **GIVEN** entry with tag color `#E06C75`
- **WHEN** detail view opens
- **THEN** accent bar renders at 8px in `#E06C75`
- **AND** background tinted at 8% opacity
- **GIVEN** entry with no tags
- **WHEN** detail view opens
- **THEN** no accent bar or tint rendered

---

## PR 2 — Tag Color ≠ Version Bump

**Domain**: `tags-colors` (modified)

### MODIFIED Requirements

#### Tag color updates MUST NOT bump version/updatedAt

When ONLY `tagsColors` changes, version and updatedAt MUST remain unchanged. Any other field change (`title`, `content`, `tags`, `type`, `secret`) continues bumping.
(Previously: every UpdateEntry call incremented version and set updatedAt = DateTime.now())

- **GIVEN** entry at version 5, updatedAt = "2026-05-30 12:00"
- **WHEN** user picks a new tag color only
- **THEN** version is 5, updatedAt unchanged
- **GIVEN** entry at version 5
- **WHEN** user edits title AND changes a tag color in one operation
- **THEN** version is 6, updatedAt = now
- **GIVEN** entry at version 5
- **WHEN** user removes a tag (changes `tags` list) with no color change
- **THEN** version is 6, updatedAt = now

---

## PR 3 — Tag Management Screen *(contract)*

**Domain**: `tag-management` (new)

Settings section listing all unique tags from `entries.tags`. Each with rename, delete, per-tag `is_secure` toggle. Delete = tombstone (`deleted_at`); entries keep the string, UI hides it.

### Requirements (detailed later)

- MUST aggregate tags from `entries` table
- MUST display alphabetically under Settings
- MUST rename tag → update all entries
- MUST set tombstone on delete — entries preserved
- MUST gate list entry visibility via `effectiveAuth = requiresAuth || is_secure`
- MUST persist in new `tag_settings` table (id, name, is_secure, deleted_at)
- SHOULD reconcile color map keys on rename

### Constraints

Budget ~700 lines; split foundation (table+DAO+UC) and UI if exceeded.

---

## PR 4 — Inline Expand *(contract)*

**Domain**: `inline-expand` (new)

EntryCard gains expandable content: single tap expands/collapses inline, double tap navigates to detail.

### Requirements (detailed later)

- MUST toggle expand on single tap
- MUST navigate on double tap
- MUST show full content + tag chips when expanded
- MUST collapse previous card on new tap
- MUST disable expand for credentials (double-tap only)
- MUST animate <200ms

### Constraints

Additive only — no EntryCard contract changes. Double-tap: 300ms window.

---

## PR 5 — Merge Temporal *(contract)*

**Domain**: `merge-temporal` (new)

Multi-select (list/grid) → merge editor (plain text) → save-as-new note. Originals untouched.

### Requirements (detailed later)

- MUST support multi-select via long-press
- MUST allow selecting ≥2 entries
- MUST concat as `-- {title} --\n\n{content}\n\n` into text editor
- MUST allow editing before save
- MUST save as new `note` entry
- MUST NOT preserve formatting

### Constraints

Plain text only. Max 20 entries per merge.

---

## Out of Scope

Tag cloud, statistics, free palette, formatting in merge, FTS5 changes, color reconciliation on rename.