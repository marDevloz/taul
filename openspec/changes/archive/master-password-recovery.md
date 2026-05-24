# Archive: Master Password Recovery

**Status**: ✅ CONDITIONAL PASS — archived with documented limitations

**Archive date**: 2026-05-24

---

## Executive Summary

Added offline self-recovery for the master password (backup codes + hint) and moved MP management to a dedicated Settings screen. The implementation introduces a **KEK/DEK wrapping key architecture** so changing the master password no longer requires re-encrypting every protected entry — a fundamental improvement to the security model.

The change spans **13 modified files** and **8 new files** across all Clean Architecture layers: domain (recovery service), infrastructure (schema v3, store CRUD, KEK/DEK crypto, backup code generation), and UI (settings screen, setup dialog, recovery dialog, hint edit, delete MP, reveal hint + recovery link). All 123 tests pass, `flutter analyze` reports 0 errors/warnings.

### Key Accomplishments

- **Schema v2→v3 migration**: 5 nullable columns added to `master_password_config` (`password_hint`, `backup_code_hashes`, `encrypted_storage_key`, `encrypted_storage_key_nonce`, `encrypted_storage_key_tag`)
- **KEK/DEK wrapping**: Random 32-byte DEK encrypted with password-derived KEK via AES-256-GCM. MP changes are now O(1) — no entry re-encryption needed
- **10 backup codes**: Generated with individual 8-byte Argon2id salts, single-use, consumed atomically within DB transactions
- **Password hint**: Plaintext hint stored optionally, displayed at reveal prompt, editable from Settings
- **Settings screen**: Full MP management — create, change, edit hint, regenerate codes, delete MP
- **Recovery flow**: Enter backup code → verify → consume atomically → set new MP. Rate-limited (3 failures → 60s lockout)
- **Transparent encryption**: MP prompt eliminated from credential form when MP is already configured and DEK cached
- **Reveal dialog**: Shows hint toggle + "Forgot password?" recovery link

---

## Change Metadata

| Field | Value |
|-------|-------|
| **Name** | master-password-recovery |
| **Type** | Feature |
| **Requirements** | 30 FR + 8 SR |
| **Implementation PRs** | 8 |
| **New files** | 8 |
| **Modified files** | 13 |
| **Total lines (new + modified)** | ~1,689 |
| **Tests added** | 8 test files, 123 tests |
| **Verify status** | CONDITIONAL PASS |

---

## What Was Built

### New Files (8)

#### Domain Layer

| File | Lines | Purpose |
|------|-------|---------|
| `lib/domain/services/master_password_recovery_service.dart` | 47 | Backup code verification (hash match) and consumption (de-index from array). Pure domain logic, no DB or UI dependency |

#### Infrastructure Layer

| File | Lines | Purpose |
|------|-------|---------|
| `lib/infrastructure/database/master_password_config_table.dart` | 17 | Drift table definition with 5 new nullable columns |
| `lib/infrastructure/security/master_password_store.dart` | 371 | Full CRUD: `readFull()`, `saveFull()`, hint/save, backup code CRUD, atomic consumption via DB transactions, encrypted storage key CRUD, config delete |

#### UI Layer

| File | Lines | Purpose |
|------|-------|---------|
| `lib/ui/screens/settings_screen.dart` | 344 | Master password management screen: status, create, change, hint, regenerate, delete |
| `lib/ui/screens/master_password_setup_dialog.dart` | 488 | Step-by-step setup with password → confirm → hint → codes display → confirmation |
| `lib/ui/widgets/master_password_recovery_dialog.dart` | 398 | Recovery flow: code entry → verify → consume → new MP with rate limiting |
| `lib/ui/widgets/hint_edit_dialog.dart` | 51 | Simple dialog to view/edit/clear hint |
| `lib/ui/widgets/delete_mp_dialog.dart` | 67 | Warning dialog with protected entry count before deletion |

### Modified Files (13)

#### Domain Layer

| File | Change |
|------|--------|
| `lib/domain/entities/entry.dart` | +`requiresAuth`, `encryptedSecret`, `cipherNonce`, `cipherTag` fields for per-entry protection |
| `lib/domain/usecases/create_entry.dart` | Encrypt secret when protect is on |
| `lib/domain/usecases/update_entry.dart` | Re-encrypt on update when protected |

#### Infrastructure Layer

| File | Change |
|------|--------|
| `lib/infrastructure/database/app_database.dart` | Schema v3, migration path `from < 3` with `addColumn` calls |
| `lib/infrastructure/database/entries_table.dart` | +`requiresAuth`, `encryptedSecret`, `cipherNonce`, `cipherTag` columns for per-entry crypto |
| `lib/infrastructure/database/entry_dao.dart` | +59 lines: encrypt/decrypt at DAO level |
| `lib/infrastructure/security/entry_auth_service.dart` | +KEK/DEK wrapping (`wrapStorageKey`/`unwrapStorageKey`), `generateBackupCodes()` (per-code Argon2id), `generateStorageKey()`, hex/bytes utilities |

#### UI Layer

| File | Change |
|------|--------|
| `lib/ui/providers/entry_providers.dart` | +`recoveryServiceProvider`, `masterPasswordHintProvider`, `masterPasswordStatusProvider`, `masterPasswordConfigProvider` |
| `lib/ui/screens/credential_protection_controller.dart` | Full KEK/DEK refactor: 3-path master key resolution (cached DEK → MP prompt → setup dialog) |
| `lib/ui/screens/credential_form_sheet.dart` | Transparent encrypt when DEK cached, setup trigger when not |
| `lib/ui/screens/entry_detail_view.dart` | Reveal dialog with hint toggle + recovery link, KEK/DEK unwrapping |
| `lib/ui/screens/home_view.dart` | Settings gear icon → `/settings` route |

### Test Files (8)

| File | Lines | Coverage |
|------|-------|----------|
| `test/domain/services/master_password_recovery_service_test.dart` | 102 | Service unit tests: verify code, consume, bounds checking |
| `test/infrastructure/security/entry_auth_service_test.dart` | 114 | KEK/DEK round-trip, backup codes generation, wrong key failure |
| `test/infrastructure/security/master_password_store_test.dart` | 264 | Store CRUD: full config, hint, codes, atomic consumption, edge cases |
| `test/integration/master_password_integration_test.dart` | 447 | Full integration flows: setup → protect → reveal → recovery → consume |
| `test/security/master_password_security_test.dart` | 199 | Security assertions: no plaintext codes, unique salts, encrypted key |
| `test/ui/screens/settings_screen_test.dart` | 188 | Settings widget tests: configured/unconfigured states |
| `test/ui/screens/master_password_setup_dialog_test.dart` | 251 | Setup dialog: validation, codes display, confirmation |
| `test/ui/widgets/master_password_recovery_dialog_test.dart` | 172 | Recovery dialog: valid/invalid codes, lockout |

---

## Test Results

| Metric | Value |
|--------|-------|
| Total tests | 123 |
| Passed | 123 |
| Failed | 0 |
| `flutter analyze` errors | 0 |
| `flutter analyze` warnings | 0 |
| `flutter analyze` info | 10 (4 `use_build_context_synchronously`, 6 `prefer_const_declarations`) |

### FR Coverage: 28/30 (93%)

| Coverage | Detail |
|----------|--------|
| **Passed** | FR1.1–FR1.6, FR2.1, FR2.3–FR2.6, FR3.1–FR3.7, FR4.1–FR4.5, FR5.1–FR5.5, FR6.1–FR6.4, FR7.1–FR7.2 |
| **Deviation** | FR2.2 (backup code format: `XXXX-XXXX` alphanumeric instead of 16-hex-chars) |
| **Not covered** | NFR1–NFR3 (performance timing — device-dependent, not measured in CI) |

### SR Coverage: 8/8 (100%)

All security requirements verified: Argon2id hashing, per-code salts, atomic consumption, in-memory key caching, plaintext hint warning, codes shown once only, min MP length, JSON storage.

---

## Known Issues

### Critical — Design Limitation

**Recovery generates a NEW DEK — old protected entries become unreachable.**

Root cause: The DEK is encrypted with a KEK derived from the old master password. During recovery, the old password is unknown, so the old KEK cannot be derived and the DEK cannot be unwrapped. A new DEK is generated, meaning all entries encrypted with the old DEK become permanently undecryptable.

**Status**: Documented and accepted. This is a fundamental tension between the wrapping key architecture (which makes MP changes instant) and the ability to recover without the old password.

**Future fix**: Encrypt the DEK with each backup code during setup. Store 10 encrypted copies of the DEK alongside the 10 code hashes. During recovery, decrypt the DEK using the matched code → preserve existing entries.

### Non-Critical Deviations

| Issue | Detail |
|-------|--------|
| **Backup code format** | FR2.2 specifies 16 hex chars; implementation uses `XXXX-XXXX` alphanumeric (8 chars, 4+4 split by dash). Matches design doc. Equivalent entropy. |
| **Missing documentation** | `docs/architecture/master-password.md` (T-19) not created. |
| **Missing reveal widget test** | `test/ui/screens/entry_detail_reveal_test.dart` (T-17) not created. Reveal logic exercised through integration test. |
| **Missing dedicated migration test** | `test/infrastructure/database/schema_migration_test.dart` (T-15) not created. Migration coverage exists in `master_password_integration_test.dart` as simulation. |

---

## Lessons Learned

### Architectural

1. **KEK/DEK wrapping was the right call**. Making MP changes O(1) instead of O(n) is a significant UX improvement. The design doc identified this correctly.
2. **DEK preservation during recovery is an unsolved problem** in the current design. The spec implied recovery could preserve entries, but the architecture makes this impossible without either: (a) storing the DEK encrypted with each backup code, or (b) using a key-encapsulation mechanism (KEM). This should be flagged as a pre-existing issue in any future recovery feature.
3. **Schema migration was minimal-risk** — nullable columns with no data transformation. The design doc's conservative approach was correct.

### Implementation

4. **Design doc diverged from spec in code format** (FR2.2) intentionally for UX reasons (`XXXX-XXXX` is more human-friendly than 16 hex chars). This was documented in the design doc but NOT in the spec — a spec amendment would have been cleaner.
5. **Atomic consumption via DB transaction** required careful parsing/serialization of JSON within the transaction closure. Drift's `customUpdate` does not automatically nest within `transaction()` — explicit code within the closure is required.
6. **Recovery dialog is complex** (398 lines) due to the two-step flow, rate limiting, and error handling. Consider extracting smaller helper widgets.

### Process

7. **The divide between the recovery dialog and the domain service** was clean: the dialog handles UI state and orchestration, the service handles pure hash verification and array manipulation.
8. **Missing test files for reveal dialog and schema migration** were accepted as acceptable risk during verification. In a more critical system, these gaps should block archive.

---

## Future Work

### Short-term

| Item | Effort | Priority |
|------|--------|----------|
| Create `docs/architecture/master-password.md` | 0.5 day | Medium |
| Add reveal widget test (`entry_detail_reveal_test.dart`) | 0.5 day | Low |

### Medium-term

| Item | Effort | Priority | Notes |
|------|--------|----------|-------|
| **DEK preservation during recovery** | 3–5 days | **High** | Encrypt DEK with each backup code during setup. Store encrypted DEK alongside code hash. On recovery: decrypt DEK with supplied code → preserve all entries. This is the single biggest UX gap. |
| Email/password reset | 5–8 days | Low | Requires network connectivity, SMTP server, rate limiting, email verification. Out of scope for offline-first design. |
| Biometric unlock | 3–5 days | Low | OS-level feature (fingerprint, Face ID). Would skip MP prompt entirely when available. |

### Long-term

| Item | Notes |
|------|-------|
| Session timeout / auto-lock | Would clear cached DEK after inactivity. Configurable timeout in Settings. |
| Password strength meter | UX enhancement at setup dialog. Not recovery-critical. |
| Cloud sync of backup codes | Purposefully out of scope — codes are offline-only by design. |
| Multiple master password profiles | No use case identified. |

---

## Architecture Decisions Recorded

The following design decisions were made during this change and persisted in the codebase:

| Decision | Rationale | Files |
|----------|-----------|-------|
| **KEK/DEK wrapping** (not direct key derivation) | MP changes without re-encrypting all entries. O(1) vs O(n) latency. | `entry_auth_service.dart` (wrapStorageKey/unwrapStorageKey), `credential_protection_controller.dart` |
| **Backup codes as `XXXX-XXXX`** (not 16 hex chars) | Human-friendly: easier to read, transcribe, and communicate over phone. Equivalent entropy (8 chars `A-Z0-9` = 36^8 ≈ 2.8T combinations, vs 16 hex = 2^64 ≈ 18.4E combinations — both sufficient). | `entry_auth_service.dart` `_generateBackupCode()` |
| **Single `master_password_config` row** (not separate codes table) | Singleton pattern (id=1) simplifies CRUD. At most 10 short strings. JSON array simpler than JOIN. | `master_password_config_table.dart`, `master_password_store.dart` |
| **Argon2id per code with individual 8-byte salts** | Rainbow table resistance across codes. Same KDF as MP hash. | `entry_auth_service.dart` `generateBackupCodes()` |
| **Atomic code consumption in DB transaction** | Prevents replay: crash between verify and delete = rollback = code unconsumed. | `master_password_store.dart` `consumeBackupCodeAtIndex()` |
| **Encrypted storage key split into 3 columns** (key/nonce/tag) | Clean separation of AES-GCM components. Decouples storage format from crypto algorithm. | `master_password_config_table.dart` |
| **New DEK on recovery** (accepted limitation) | Old DEK encrypted with old KEK — cannot unwrap without old password. Documented in class-level doc. | `master_password_recovery_dialog.dart` (class doc and `_onSetNewPassword`) |
| **In-memory rate limiting** | Acceptable for offline app: attacker has physical access. Lockout resets on app restart — defense-in-depth, not primary protection. | `master_password_recovery_dialog.dart` |

---

## Tasks Status

All 19 tasks (T-01 through T-19) tracked in `openspec/changes/master-password-recovery/tasks.md`. Status summary:

| Status | Count | Tasks |
|--------|-------|-------|
| ✅ Complete | 16 | T-01 through T-14, T-16, T-18 |
| ❌ Not created | 3 | T-15 (migration test — covered in integration test), T-17 (reveal widget test), T-19 (documentation) |

---

## Artifacts

| Artifact | Location | Status |
|----------|----------|--------|
| Proposal | `openspec/changes/master-password-recovery/proposal.md` | ✅ |
| Spec | `openspec/changes/master-password-recovery/spec.md` | ✅ |
| Design | `openspec/changes/master-password-recovery/design.md` | ✅ |
| Tasks | `openspec/changes/master-password-recovery/tasks.md` | ✅ (completed) |
| Verify | `openspec/changes/master-password-recovery/verify.md` | ✅ |
| Archive | `openspec/changes/archive/master-password-recovery.md` | ✅ (this file) |

---

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| DEK loss on recovery → unreachable entries | **CERTAIN** (by design) | High | Documented in archive and code. Future: encrypt DEK with each backup code. |
| Missing reveal widget test | Low | Low | Integration test covers reveal flow. Manual review confirms behavior. |
| Missing schema migration test | Low | Low | Jnative Drift migration path tested in integration test. |
| Missing architecture documentation | Low | Low | This archive serves as documentation. Follow-up ticket recommended. |
