# Delta: Lockout Enforcement (PR1 — Finding B)

## ADDED Requirements

### R1: Failed attempt tracking per prompt type

The system MUST track failed authentication attempts separately for master password (MP) prompts and backup code prompts. Each prompt type maintains an independent counter and lockout timer.

#### Scenario: MP attempt counter increments on failure

- GIVEN no prior failed attempts
- WHEN user submits an incorrect master password
- THEN the MP failed attempt counter increments to 1
- AND the response time is under 2 seconds

#### Scenario: Backup code attempt counter increments on failure

- GIVEN no prior failed backup code attempts
- WHEN user submits an incorrect backup code
- THEN the backup code failed attempt counter increments to 1

### R2: MP lockout after 5 failed attempts

The system MUST enforce a 30-second lockout after 5 consecutive failed master password attempts. During lockout, the MP prompt SHALL display remaining lockout time and reject input.

#### Scenario: Lockout triggers at 5 failures

- GIVEN 4 prior failed MP attempts (counter = 4)
- WHEN user submits a 5th incorrect MP
- THEN the MP prompt enters lockout state for 30 seconds
- AND the UI displays "Try again in X seconds"

#### Scenario: Lockout blocks submission

- GIVEN MP prompt is in lockout state (15 seconds remaining)
- WHEN user submits any input
- THEN the submission is rejected without checking the password
- AND the lockout timer is NOT reset

### R3: Backup code lockout after 3 failed attempts

The system MUST enforce a 60-second lockout after 3 consecutive failed backup code attempts. During lockout, the backup code prompt SHALL reject input.

#### Scenario: Lockout triggers at 3 failures

- GIVEN 2 prior failed backup code attempts
- WHEN user submits a 3rd incorrect backup code
- THEN the backup code prompt enters lockout state for 60 seconds

### R4: Counter reset on success

The system MUST reset the failed attempt counter for a prompt type to 0 after a successful authentication of that type.

#### Scenario: Successful MP resets counter

- GIVEN 3 prior failed MP attempts
- WHEN user submits a correct master password
- THEN the MP failed attempt counter resets to 0
- AND no lockout is active

### R5: Counter reset after lockout expires

The system MUST reset the failed attempt counter to 0 when a lockout timer expires, allowing fresh attempts.

#### Scenario: Lockout expiry resets counter

- GIVEN MP prompt is in lockout state
- WHEN the 30-second lockout timer expires
- THEN the MP failed attempt counter resets to 0
- AND the prompt accepts input again

### R6: In-memory persistence scope

The lockout counters SHALL be held in memory only. App restart resets all counters and lockout timers. This is acceptable for a desktop application — the OS login provides an outer security boundary.

#### Scenario: App restart clears lockout

- GIVEN MP prompt is in lockout state with 20 seconds remaining
- WHEN the application is restarted
- THEN the MP failed attempt counter is 0
- AND no lockout is active

### R7: LockoutService interface

The system SHALL provide a `LockoutService` class with methods: `recordFailure(promptType)`, `isLockedOut(promptType)`, `remainingSeconds(promptType)`, `reset(promptType)`. `promptType` is an enum: `masterPassword`, `backupCode`.
