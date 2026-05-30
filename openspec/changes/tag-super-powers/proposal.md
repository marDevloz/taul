# Proposal: Tag Super Powers

## Intent

Add 6 interaction features to turn tags from passive labels into active touchpoints: copyable titles, tag color ≠ version bump, detail styling, tag management CRUD, merge temporal, inline expand.

## Scope

**In**: Copyable titles via SelectableText. Tag color updates skip version/updatedAt. Detail view accent bar + background tint. Tag management screen (CRUD + per-tag `is_secure` flag). Merge temporal (multi-select → TXT → save-as-new). Inline expand (single click expand, double click → detail). 5 chained PRs at ≤400 lines Δ each.

**Out**: 34 pre-existing test failures. Tag rename color reconciliation (accepted edge). Tag cloud/statistics. Custom palette. Entry formatting in merge.

## Capabilities

**New**: `tag-management` (global registry DB table, CRUD admin, per-tag security), `merge-temporal` (merge editor → save-as-new), `inline-expand` (expandable cards, click semantics).

**Modified**: `tags-colors` — color updates no longer bump version/updatedAt.

## Approach

Additive, independent delivery per PR. PR 3 splits if over budget. Auth: `requiresAuth \|\| is_secure` — single gate.

| PR | Features | Δ | Layers |
|----|----------|---|--------|
| 1 — Quick Wins | Copyable titles + detail styling | ~80 | ui |
| 2 — Version Sep | `updateEntryTagsColors` use case | ~100 | domain + infra |
| 3 — Tag Mgmt | `tag_settings` table, CRUD, security | ~700 | all |
| 4 — Inline Expand | Expandable cards, unlock in list | ~300 | ui |
| 5 — Merge Temporal | Multi-select, merge editor, save | ~400 | ui + domain |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| PR 3 over budget | High | Split: foundation (table+dao+UC) then UI |
| Double-gate auth | Med | Spec: `effectiveAuth = requiresAuth \|\| is_secure` |
| Merge loses formatting | Med | Plain text only, document limitation |

## Rollback Plan

**PR 1/2/4/5**: Revert commit — no schema changes. **PR 3**: `DROP TABLE IF EXISTS tag_settings` — safe, no entry data dependency.

## Dependencies

`tags-colors` schema (v6), `TagPalette`, `TagColorMixer`, `UpdateEntry` use case, existing Settings screen.

## Success Criteria

- [ ] Title copyable via long-press
- [ ] Tag color updates: version/updatedAt unchanged
- [ ] Detail view: accent bar + background tint
- [ ] Tag management: create, rename, delete, toggle secure
- [ ] Secure tag gates entry in list view
- [ ] Single click expands, double click opens detail
- [ ] Merge ≥2 entries → editable TXT → saves new entry
- [ ] All PRs ≤400 lines Δ, no regression on entry CRUD
