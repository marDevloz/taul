# Proposal: user-manual

## Intent

Users have no in-app reference for Taúl's features. They discover keyboard shortcuts, entry types, and security behavior by trial and error. A dedicated manual screen inside Settings gives them a browsable, offline reference without leaving the app.

## Scope

### In Scope
- New `UserManualScreen` with expandable sections (`ExpansionTile`)
- Route `/settings/manual` — child of `/settings`
- Entry point in Settings screen (ListTile after Tag Management)
- Sections: Entry Types, Quick-Add Syntax, Tags, Merge, Credential Protection, Keyboard Shortcuts, Settings Overview
- Content as Flutter rich text — no Markdown parser, no WebView, no network
- Pure static content embedded in Dart code (no assets, no i18n)
- Screen respects theme and font scale

### Out of Scope
- `docs/manual.md` standalone file (deferred to a follow-up)
- Search within the manual
- Interactive tutorials or onboarding flow
- Localization beyond Spanish (matching app UI language)
- Linkable anchors or deep sections

## Capabilities

### New Capabilities
- `user-manual`: Offline in-app reference screen covering all entry types, quick-add syntax, tags, merge, credential protection, keyboard shortcuts, and settings overview. Content embedded in Dart as static rich text, organized in expandable sections.

### Modified Capabilities
- None

## Approach

Single new screen widget (`UserManualScreen`) in `lib/ui/screens/`. Content modeled as a `List<ManualSection>` where each section has a title, icon, and list of `ManualParagraph` (either text or bullet). The widget renders them as `ExpansionTile` → `Column` of `SelectableText.rich()` with `TextSpan` children for bold/italic/inline-code formatting.

Route registered as child of `/settings` in `app.dart` (`/settings/manual`). Settings screen gets a new `ListTile` in the section after "Gestionar etiquetas".

No providers, no state, no persistence — pure static UI.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/ui/screens/user_manual_screen.dart` | **New** | Manual screen with all expandable sections |
| `lib/ui/screens/settings_screen.dart` | Modified | Add ListTile → `/settings/manual` |
| `lib/app.dart` | Modified | Add `/settings/manual` child route, import new screen |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Content drifts from actual app behavior | Medium | Manual is in code next to the features it documents; update on relevant feature changes |
| ExpansionTile depth makes navigation tedious | Low | Flat section list, max 2 levels deep; users see all section titles at a glance |
| Rich text formatting gets verbose in Dart | Low | Extract `ManualSection`/`ManualParagraph` helpers; keep content readable |

## Rollback Plan

Remove the route from `app.dart`, remove the ListTile from `settings_screen.dart`, delete `user_manual_screen.dart`. No migration, no data, no state — zero-cost revert.

## Dependencies

- None. Uses only Flutter Material (`ExpansionTile`, `SelectableText`, `TextSpan`).

## Success Criteria

- [ ] Screen renders all sections with correct content
- [ ] Each section is expandable/collapsible via `ExpansionTile`
- [ ] Rich text formatting (bold, italic, inline code) renders correctly
- [ ] Entry point visible in Settings, navigates to `/settings/manual`
- [ ] All existing analyzer checks pass, no new issues
