# Tasks: User Manual

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~280–340 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Suggested split | Single PR |
| Delivery strategy | single-pr |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: Low

## Phase 1: Content Model & Screen

- [ ] 1.1 Create `lib/ui/screens/user_manual_screen.dart` — define `ManualSection` (title, icon, paragraphs) and `ManualParagraph` (sealed: text vs bullet) data classes
- [ ] 1.2 Implement static content for all 7 sections: Entry Types, Quick-Add Syntax, Tags, Merge, Credential Protection, Keyboard Shortcuts, Settings Overview — rich `TextSpan` with bold/italic/inline-code formatting
- [ ] 1.3 Build `ExpansionTile` per section with `Column` of `SelectableText.rich()` per paragraph — pure widget, no providers, no state

## Phase 2: Routing & Entry Point

- [ ] 2.1 Register `/settings/manual` as child of `/settings` in `lib/app.dart` — add import and `GoRoute(name: 'manual')`
- [ ] 2.2 Add `ListTile` in `lib/ui/screens/settings_screen.dart` after "Gestionar etiquetas" — icon `Icons.menu_book`, title "Manual de usuario", navigates via `context.push('/settings/manual')`

## Phase 3: Verification

- [ ] 3.1 Run `dart analyze` — zero new issues
- [ ] 3.2 Manual check: all 7 sections render with correct content, expand/collapse works, navigation Settings → Manual → back flows correctly
- [ ] 3.3 Manual check: bold, italic, and monospace inline-code formatting renders correctly in rich text
