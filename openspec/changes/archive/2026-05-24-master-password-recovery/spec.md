# Master Password Recovery — Delta Spec

Add offline recovery (backup codes + hint) to master password and move management to a Settings screen, enabling transparent encryption in the credential form without prompting for the master password every time.

## Executive Summary

Currently the master password (MP) has no recovery path — if forgotten, all protected credentials are lost. MP management is embedded in the credential form flow with no dedicated Settings UI. This delta adds two new capabilities:

1. **Master Password Settings** — a dedicated screen to create, change, view status, set hint, and regenerate backup codes
2. **Master Password Recovery** — offline self-recovery via 10 single-use backup codes (Argon2id-hashed) and a plaintext hint

Both capabilities build on existing crypto (AES-256-GCM, Argon2id) with no external dependencies. Schema v2→v3 migration adds two nullable columns to `master_password_config`. The existing `CredentialProtectionController` is refactored to skip MP prompts when MP is already configured (transparent encrypt), and to trigger the setup dialog when MP is not configured.

---

## Functional Requirements

### FR1 — Master Password Settings Screen

| ID | Requirement | Acceptance Criteria |
|----|-------------|-------------------|
| FR1.1 | New Settings screen accessible from app navigation | Tap settings icon → navigate to `/settings/mp` |
| FR1.2 | Screen shows MP status: "Configured" or "Not configured" | Status label + icon updates reactively via provider |
| FR1.3 | "Create Master Password" flow when not configured | Step-by-step: password → confirm → hint (optional) → show backup codes → save |
| FR1.4 | "Change Master Password" when configured | Prompt current MP → new MP + confirm → new hint (optional) → regenerate codes (optional) |
| FR1.5 | Cancel at any step returns to Settings without side effects | No partial writes. Only state change on final confirm. |
| FR1.6 | Minimum MP length: 8 characters | Validation enforced at UI level |

### FR2 — Backup Code Generation

| ID | Requirement | Acceptance Criteria |
|----|-------------|-------------------|
| FR2.1 | 10 codes generated at MP creation | Exactly 10 codes, each displayed once after setup |
| FR2.2 | Each code is a random 8-byte hex string (16 hex chars) | Generated via `Random.secure()`, output: `String` of 16 hex lowercase chars |
| FR2.3 | Codes displayed once with copy-all and save-as-text options | User explicitly acknowledges copy/save before codes are hidden |
| FR2.4 | "I saved my codes" confirmation step required | Button enabled only after user confirms |
| FR2.5 | Codes can be regenerated from Settings at any time | Regenerate replaces ALL 10 hashes atomically |
| FR2.6 | Each code hashed with Argon2id (same params as MP) before storage | `argon2id(memory=65536, iterations=2, parallelism=1, hashLength=32)` |

**Regenerate flow**: prompt "This invalidates all existing codes" → confirm → generate 10 new codes → hash → atomically replace `backup_code_hashes` → display codes once. Old codes are immediately invalid.

### FR3 — Backup Code Recovery

| ID | Requirement | Acceptance Criteria |
|----|-------------|-------------------|
| FR3.1 | "Forgot password?" link at MP prompt (credential reveal) | Tap → opens recovery flow |
| FR3.2 | Recovery flow: enter backup code → verify → set new MP | Steps: enter code → verify hash match → consume code → new MP form |
| FR3.3 | Each code is single-use | After successful match, delete that hash from `backup_code_hashes` array within the same transaction |
| FR3.4 | Verify+consume is atomic | Single SQL transaction: read hashes → verify → write updated array. If write fails, code remains unconsumed. |
| FR3.5 | After successful recovery, user sets new MP | Standard MP create flow (FR1.3), hint pre-filled from existing if any |
| FR3.6 | Failed attempts: no lockout | Inform user of failure, allow retry with remaining codes. Max 10 attempts total (limited by code count anyway) |
| FR3.7 | Recovery does NOT invalidate existing codes | Existing codes remain valid unless explicitly regenerated |

**Recovery flow pseudocode**:

```
1. prompt: "Enter one of your backup codes"
2. if no input or empty → return to prompt
3. read current backup_code_hashes from DB
4. for each hash in backup_code_hashes:
     if argon2id.verify(code, hash) == match:
       remove hash from array
       write updated array to DB (single UPDATE)
       proceed to "Set new MP" flow
       return
5. show "Invalid code. X attempts remaining." → back to step 1
```

**NOTE**: Argon2id for backup codes uses the **same** parameters as MP hashing (memory=65536, iterations=2, parallelism=1, hashLength=32) but with a **different salt per code** (8 bytes each, stored alongside the hash in `backup_code_hashes`). Each hash entry in the JSON array is `"<salt_hex>:<hash_hex>"`.

### FR4 — Password Hint

| ID | Requirement | Acceptance Criteria |
|----|-------------|-------------------|
| FR4.1 | Hint stored during MP setup (optional field) | Text field in setup dialog, max 200 chars |
| FR4.2 | Hint editable from Settings | Change hint independent of MP change |
| FR4.3 | Hint displayed at MP prompt | Text: "Hint: {hint}" below the password field in the reveal dialog |
| FR4.4 | Hint is plaintext in DB | Column `password_hint TEXT NULLABLE` in `master_password_config` |
| FR4.5 | Clearing hint is allowed | User can delete hint text → writes NULL |

### FR5 — Transparent Encryption Flow (modified)

| ID | Requirement | Acceptance Criteria |
|----|-------------|-------------------|
| FR5.1 | If MP is configured, "Protect" toggle encrypts silently | No dialog, no prompt. Master key used from in-memory cache. |
| FR5.2 | If MP is configured but key cache expired, prompt for MP | `MasterPasswordNotifier.cachedKey` is null → show MP prompt dialog |
| FR5.3 | If MP is NOT configured, "Protect" toggle triggers setup dialog | Same as FR1.3: create MP → show codes → hint → save → then encrypt |
| FR5.4 | MP prompt only shown at REVEAL (decrypt) | Viewing secret triggers MP prompt if `requiresAuth=true` and key not cached |
| FR5.5 | Cancel at setup during encryption → "Protect" remains off | Entry saved unencrypted. No partial state. |

### FR6 — Credential Reveal with MP Prompt + Hint + Recovery

| ID | Requirement | Acceptance Criteria |
|----|-------------|-------------------|
| FR6.1 | Reveal dialog shows: MP field + "Show hint" link + "Forgot password?" link | Three UI elements: password field, hint link, recovery link |
| FR6.2 | "Show hint" reveals hint (tapping it) | Shows text: "Hint: {hint}" inline |
| FR6.3 | "Forgot password?" opens backup code recovery flow | Navigates to FR3 flow |
| FR6.4 | Successful MP entry caches key and reveals secret | Key stored in `_masterPasswordNotifier.setMasterPassword()` |

### FR7 — App Bar Navigation

| ID | Requirement | Acceptance Criteria |
|----|-------------|-------------------|
| FR7.1 | Settings icon in app bar (home view) | Gear icon → navigates to Settings screen |
| FR7.2 | Settings screen has "Master Password" section | Section with status, buttons for create/change/hint/codes |

---

## Non-Functional Requirements

| ID | Requirement | Verification |
|----|-------------|-------------|
| NFR1 | All crypto ops complete within 2 seconds on a mid-range device | `argon2id(memory=65536, iterations=2)` ≤ 1.5s. AES-GCM ≤ 100ms. |
| NFR2 | Backup code verification ≤ 2s | Single Argon2id verify per attempt, worst case: 10 attempts |
| NFR3 | Migration v2→v3 completes in < 50ms | Simple ALTER TABLE ADD COLUMN, no data transformation |
| NFR4 | No regressions in existing tests | `flutter test` passes; all existing tests green |
| NFR5 | New code coverage ≥ 80% | Line coverage for new files (controller, providers, services) |
| NFR6 | No secrets in logs | All Argon2id hashes/logic must use `dart:developer` log levels SKIP_DEBUG or none |

---

## Security Requirements

| ID | Requirement | Rationale |
|----|-------------|-----------|
| SR1 | Backup codes hashed with Argon2id — NOT SHA, NOT bcrypt | Same KDF as MP hash. Argon2id is memory-hard, resistant to GPU/ASIC. |
| SR2 | Each backup code gets its own 8-byte random salt | Prevents rainbow table across codes |
| SR3 | Code consumed atomically within DB transaction | Prevents replay: if app crashes between verify and delete, rollback ensures code unused |
| SR4 | Master key cached in memory only — never persisted to disk | `MasterPasswordNotifier.cachedKey` is a `Uint8List?` in RAM. Cleared on app lifecycle events. |
| SR5 | Hint is plaintext — user warned at setup | "Your hint is stored as plain text and visible to anyone with device access" |
| SR6 | Backup codes shown only once after generation/regeneration | After confirmation dialog dismissed, codes are never re-displayed. User must regenerate for new set. |
| SR7 | Minimum MP length: 8 characters | Prevents brute force on low-entropy passwords |
| SR8 | `backup_code_hashes` column is TEXT — stores JSON array of `"<salt_hex>:<hash_hex>"` strings | No structured encryption needed; hashes are already one-way. JSON for simple serialization. |

**Security tradeoff accepted**: Backup codes are hashed one-way, so if all 10 codes are lost AND MP is forgotten, recovery is impossible. This is explicitly documented in the setup flow.

---

## Data Models / Schema Changes (v2 → v3)

### Current schema: `master_password_config` (v2, unchanged)

| Column | Type | Constraints |
|--------|------|-------------|
| id | INTEGER | PK, clientDefault(1) |
| password_hash_argon2 | TEXT | NOT NULL |
| salt_hex | TEXT | NOT NULL |
| created_at | TEXT (DATETIME) | NOT NULL |
| updated_at | TEXT (DATETIME) | NOT NULL |

### New schema: `master_password_config` (v3)

| Column | Type | Constraints | v2→v3 Change |
|--------|------|-------------|-------------|
| id | INTEGER | PK, clientDefault(1) | — |
| password_hash_argon2 | TEXT | NOT NULL | — |
| salt_hex | TEXT | NOT NULL | — |
| password_hint | TEXT | NULLABLE | **NEW** |
| backup_code_hashes | TEXT | NULLABLE | **NEW** |
| created_at | TEXT (DATETIME) | NOT NULL | — |
| updated_at | TEXT (DATETIME) | NOT NULL | — |

Columns `password_hint` and `backup_code_hashes` are NULLABLE for backward compatibility. When MP has been created without a hint (after migration), both columns remain `NULL`.

### `backup_code_hashes` format

JSON array of strings, each in format `"<hex_salt>:<hex_hash>"`:

```json
[
  "a1b2c3d4e5f6a7b8:3f7c...",
  "b2c3d4e5f6a7b8c9:1a2b..."
]
```

**Why JSON array over a separate table**: A single master_password_config row is always id=1 (singleton). A separate table adds complexity (join, FK) for at most 10 short strings per user. The array is always read and written together. JSON is trivial to parse with `dart:convert`.

### Migration (v2→v3)

```sql
ALTER TABLE master_password_config ADD COLUMN password_hint TEXT NULLABLE;
ALTER TABLE master_password_config ADD COLUMN backup_code_hashes TEXT NULLABLE;
```

No data transformation needed. Old v2 rows get NULL for both new columns.

### `AppDatabase` changes

| Change | Detail |
|--------|--------|
| `schemaVersion` | 2 → 3 |
| `onUpgrade` | Add `from < 3` branch with two `addColumn` calls |
| Generated file | Re-run `drift_dev` to regenerate `app_database.g.dart` |

---

## New/Modified Affected Areas

| File | Change |
|------|--------|
| `infrastructure/database/master_password_config_table.dart` | +`password_hint` +`backup_code_hashes` columns |
| `infrastructure/database/app_database.dart` | Schema v3, migration branch `from < 3` |
| `infrastructure/security/master_password_store.dart` | +`readAll()`, +`saveHint()`, +`saveBackupCodeHashes()`, +`readBackupCodeHashes()` |
| `infrastructure/security/entry_auth_service.dart` | +`generateBackupCodes()`: 10 random bytes → hex → hash each with Argon2id returning `(List<String> plainCodes, List<String> saltedHashes)` |
| `ui/providers/entry_providers.dart` | +`masterPasswordSettingsProvider`, +`masterPasswordHintProvider`, +`isMasterPasswordConfiguredProvider` |
| `ui/screens/credential_protection_controller.dart` | Refactor: if MP configured → silent encrypt; if not → setup dialog; +recovery flow delegate |
| `ui/screens/entry_detail_view.dart` | Hint display + "Forgot password?" link at reveal dialog |
| **NEW**: `ui/screens/master_password_settings_view.dart` | Full Settings screen: status, create, change, hint, regenerate |
| **NEW**: `ui/screens/master_password_recovery_view.dart` | Recovery flow: enter code → verify → set new MP |

---

## Out of Scope

| Item | Reason |
|------|--------|
| Email/password reset | Requires network, SMTP config, rate limiting. Offline-first app. |
| Biometric unlock | OS-level feature, separate capability |
| Cloud sync of backup codes | Codes are offline-only by design |
| Password strength meter | UX enhancement, not recovery-critical |
| Session timeout / auto-lock | Separate capability |
| Multiple master password profiles | No use case identified |
| Backup code printable PDF | MVP: copy + save-as-text only |
| Remote account lockout | No network dependency |
| Rate limiting on MP attempts | App runs locally; OS handles integrity |

---

## Data Flow Diagrams

### Setup Flow (first-time MP creation)

```
[User taps "Create MP"]
       |
       v
[Enter password + confirm]
       |
       v
[Optional: enter hint]
       |
       v
[10 codes generated + displayed]
       |
       v
[User confirms "I saved my codes"]
       |
       v
[save hash + salt + hint + backup_code_hashes to DB]
       |
       v
[derive master key → cache in memory]
       |
       v
[Done — status shows "Configured"]
```

### Encrypt Flow (credential form, "Protect" toggle)

```
[User toggles "Protect"]
       |
       +-- MP configured? --YES--> [encrypt silently with cached key]
       |
       NO
       |
       v
[Trigger setup dialog (same as Setup Flow)]
       |
       v
[After setup complete → encrypt]
```

### Reveal Flow (viewing credential secret)

```
[User taps "Show password"]
       |
       v
[requiresAuth? --NO--> show plaintext secret]
       |
       YES
       |
       v
[MP prompt dialog with hint + recovery link]
       |
       +-- [User enters MP] --> [verify → cache key → decrypt → show]
       |
       +-- [User taps hint] --> [show hint inline]
       |
       +-- [User taps "Forgot password?"] --> [recovery flow]
```

### Recovery Flow

```
[User taps "Forgot password?"]
       |
       v
[Enter backup code]
       |
       v
[Verify: iterate stored hashes, argon2id match?]
       |
       +-- MATCH --> [atomically consume hash → go to "Set new MP"]
       |
       NO MATCH
       |
       v
[Show "Invalid code. X attempts remaining."]
       |
       +-- retry --> [back to enter code]
       |
       +-- cancel --> [back to MP prompt]
```

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Code consumed but DB write fails | Low | High | Atomic transaction: verify + delete in single `customUpdate`. If app crashes mid-verify, code unconsumed. |
| User loses MP AND all backup codes | Medium | High | Prominent warning at setup: "Without your MP or a backup code, protected data is unrecoverable." Suggest saving codes in a password manager. |
| v3 migration on corrupted v2 DB | Low | Low | Nullable cols — no data dependency. ALTER TABLE ADD COLUMN is safe SQL even on empty DB. |
| Hint leaks sensitive info | Low | Medium | Warning at setup: "Hint is stored as plaintext." No PII validation enforced. |
| Argon2id iteration timing on slow devices | Low | Medium | Current params (65536/2/1) benchmarked < 1.5s on mid-range. Acceptable for setup/reveal — not for every action. |

---

## Acceptance Criteria Checklist

- [x] SCHEMA: v2→v3 migration adds `password_hint` + `backup_code_hashes` (both NULLABLE) to `master_password_config`
- [x] SCHEMA: Existing v2 data survives migration with NULL in new columns
- [x] SETUP: 10 backup codes generated with individual 8-byte salts, hashed with Argon2id
- [x] SETUP: Codes displayed once with copy/save, hidden after confirmation
- [x] SETUP: Hint stored (optional) during setup
- [x] SETTINGS: Status shows "Configured" / "Not configured"
- [x] SETTINGS: Change MP preserves existing hint (unless changed)
- [x] SETTINGS: Regenerate codes replaces all 10 hashes atomically
- [x] SETTINGS: Edit hint independent of MP change
- [x] ENCRYPT: Protect toggle encrypts silently when MP configured + key cached
- [x] ENCRYPT: Protect toggle triggers setup dialog when MP not configured
- [x] REVEAL: MP prompt shows hint + "Forgot password?" link
- [x] RECOVERY: Backup code entered → verified → consumed atomically → new MP set
- [x] RECOVERY: Invalid code shows feedback → retry → cancel
- [x] RECOVERY: Verify+consume is atomic — DB rollback leaves code unconsumed
- [x] SECURITY: Backup codes NOT re-displayed after initial setup/regeneration
- [x] TESTS: All existing tests pass
- [x] TESTS: New tests cover backup code generate/verify/consume
- [x] TESTS: New tests cover transparent encrypt flow
- [~] TESTS: New tests cover v2→v3 migration (covered in integration test, no dedicated migration test file)
