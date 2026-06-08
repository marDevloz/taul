# Entry Draft Specification

## Purpose

Preserve in-progress entry content when `CreateEntrySheet` is dismissed and restore it on reopen, eliminating data loss from accidental sheet closure. Draft lifecycle is tied to the create-entry sheet — one slot, latest wins.

## Functional Requirements

### Requirement: Auto-save on dismiss

When `CreateEntrySheet` is dismissed (back gesture, swipe down, or `Navigator.pop`), the system MUST save the current form state to a draft slot if any field is non-empty.

#### Scenario: Save draft on dismiss

- GIVEN the user has typed content (title, rich content, or tags) in CreateEntrySheet
- WHEN the sheet is dismissed
- THEN the draft is saved with the current title, content (Delta JSON), tags, and entry type
- AND the draft is available for restoration on next open

#### Scenario: No draft on empty dismiss

- GIVEN the user has NOT typed anything (all fields empty)
- WHEN the sheet is dismissed
- THEN no draft is saved
- AND any existing stale draft is cleared

### Requirement: Restore on open

When `CreateEntrySheet` is opened and a draft exists, the system MUST populate the form fields from the stored draft.

#### Scenario: Restore full draft

- GIVEN a saved draft exists with title, content, tags, and type
- WHEN CreateEntrySheet opens
- THEN `_titleCtrl`, `_tagsCtrl`, `_richContent`, and `_manualType` are restored from the draft
- AND the user can continue editing from where they left off

#### Scenario: Open with no draft

- GIVEN no draft exists
- WHEN CreateEntrySheet opens
- THEN the sheet opens with blank fields as usual

### Requirement: Clear on successful save

After a successful entry save, the system MUST clear the draft.

#### Scenario: Draft cleared after save

- GIVEN a draft exists and the user taps save
- WHEN the save completes successfully
- THEN the draft is cleared
- AND the next sheet open shows blank fields

### Requirement: Explicit clear

The user MAY clear the draft by clearing all fields and closing the sheet, or the system MAY clear it on a dedicated clear action.

#### Scenario: Clear fields clears draft

- GIVEN a draft exists
- WHEN the user clears all fields and dismisses the sheet
- THEN the draft is cleared

### Requirement: Single draft slot

The system MUST maintain exactly one draft slot. Each dismiss overwrites the previous draft.

#### Scenario: Last write wins

- GIVEN a draft exists with title "First"
- WHEN the user opens the sheet, replaces the title with "Second", and dismisses
- THEN the stored draft contains the "Second" version only

### Requirement: Ephemeral persistence boundary

The system SHOULD persist the draft across app restarts via `SharedPreferences`. This is intended behavior — the draft survives restarts so the user does not lose unsaved work.

#### Scenario: Draft survives restart

- GIVEN a saved draft exists
- WHEN the app is restarted and CreateEntrySheet opens
- THEN the draft is restored

### Requirement: Auto-detected type preservation

The system MUST preserve the auto-detected or manually selected entry type in the draft.

#### Scenario: Type preserved in draft

- GIVEN the user has typed content that triggers auto-detection of entry type
- WHEN the sheet is dismissed and reopened
- THEN the detected entry type is restored alongside content

## Non-functional Requirements

### NFR1: Zero save-flow impact

The draft system SHALL NOT alter, intercept, or affect the existing entry save flow. Draft save and entry save are independent operations.

### NFR2: Instant write

Draft save on dismiss SHALL use a synchronous write to `SharedPreferences` — no async delay or debounce — so draft is persisted before the widget disposes.
