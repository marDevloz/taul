# Delta for system-tags

## ADDED Requirements

### Requirement: System tags excluded from batch selection

The system MUST prevent system tags from being selected during multi-select batch delete on the tag management screen. System tags SHALL appear non-interactive (no checkbox, no selection highlight) while multi-select mode is active.

The system MUST achieve this by:
1. Checking `isSystem` on the tag entity — system tags SHALL NOT toggle selection state.
2. Providing no visual affordance for selection (no checkmark, no highlight change) on system tag tiles during multi-select mode.

#### Scenario: Cannot select system tag in batch mode

- GIVEN the user is on the tag management screen
- AND the user activates multi-select mode via long-press on a user tag
- WHEN the user taps a system tag tile (e.g., `#pendiente`)
- THEN the system tag MUST NOT become selected
- AND no checkbox overlay SHALL appear on the system tag
- AND any existing user tag selections SHALL remain unchanged

#### Scenario: Long-press on system tag does not enter multi-select

- GIVEN the user is on the tag management screen (not in multi-select mode)
- WHEN the user long-presses a system tag tile
- THEN the system SHALL NOT enter multi-select mode
- AND the existing color-picker behavior SHALL remain unchanged
