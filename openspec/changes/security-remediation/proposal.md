# Proposal: Security Remediation (4 Audit Findings)

## Intent

Security audit identified 4 findings: lockout bypass (HIGH), unencrypted SQLite (HIGH), plaintext export (MEDIUM), and DEK non-zeroing (LOW). All must be remediated. Fix order: B → A → D → C (highest risk first, independent items last).

## Scope

### In Scope
- **PR1 (Finding B)**: Lockout enforcement on master password prompts — 5-attempt limit with 30s lockout for MP, 3-attempt limit with 60s for backup codes
- **PR2 (Finding A)**: SQLCipher encryption for SQLite database — encrypt title, content, tags, metadata columns; migrate existing unencrypted DB
- **PR3 (Finding D)**: Encrypted export — passphrase-derived key wraps export payload (title, content, tags, metadata)
- **PR4 (Finding C)**: DEK zeroing — fill `Uint8List` with zeros before nulling references in `CredentialProtectionController` and `MasterPasswordNotifier`

### Out of Scope
- Hardware-backed key storage (future enhancement)
- Biometric unlock integration
- Export format changes beyond encryption (JSON schema stays v1)
- Penetration testing or external audit follow-up

## Capabilities

### New Capabilities
- `lockout-enforcement`: Attempt counting and time-based lockout for MP and backup code prompts
- `encrypted-export`: Passphrase-protected export with AES-256-GCM wrapping

### Modified Capabilities
- `master-password-settings`: R7 (No DEK leakage) — add explicit zeroing requirement
- `master-password-recovery`: R7 (No DEK leakage) — add explicit zeroing requirement

## Approach

### PR1: Lockout Enforcement (Finding B)
**Layers**: ui, infrastructure

Create a `LockoutService` in `infrastructure/security/` that tracks failed attempts per prompt type (MP vs backup code) with configurable thresholds and cooldown timers. Use `SharedPreferences` for persistence across dialog instances. Inject into `CredentialProtectionController`, `master_password_gate.dart`, and `master_password_recovery_dialog.dart`.

Key files:
- NEW: `lib/infrastructure/security/lockout_service.dart`
- MODIFY: `lib/ui/screens/credential_protection_controller.dart` (lines 323-430 — `_askForPassword`)
- MODIFY: `lib/ui/widgets/master_password_gate.dart` (lines 31-46 — `while(true)`)
- MODIFY: `lib/ui/widgets/master_password_recovery_dialog.dart` (lines 287-364 — `_failedAttempts`)
- MODIFY: `lib/ui/providers/entry_providers.dart` (line 93-100 — `MasterPasswordNotifier`)

**Lockout strategy**: In-memory counters are sufficient for a desktop app — restarting the app resets the lockout, which is acceptable. Persistent lockout (SharedPreferences) adds marginal security at cost of complexity. Recommendation: in-memory only, with configurable thresholds.

### PR2: Encrypted SQLite (Finding A)
**Layers**: infrastructure

Replace `NativeDatabase(file)` with `NativeDatabase(file, setup: ...)` using SQLCipher's `PRAGMA key` via `sqflite_common_ffi` or a Drift-compatible cipher extension. Migrate on first open: read unencrypted, write encrypted, verify, delete old file.

Key files:
- MODIFY: `lib/infrastructure/database/app_database.dart` (lines 205-209 — `_openConnection`)
- MODIFY: `lib/infrastructure/database/entries_table.dart` (lines 1-23 — column definitions stay, but encrypted at storage level)
- NEW: `lib/infrastructure/database/database_migration_service.dart` (unencrypted → encrypted migration)
- MODIFY: `pubspec.yaml` (add `sqflite_common_ffi` or `drift_sqcipher` dependency)

**Migration**: On app start, check DB encryption status. If unencrypted, prompt for MP, derive KEK, open encrypted DB, copy rows, verify row count, delete old file. Fallback: if MP unavailable, keep existing DB (graceful degradation).

### PR3: Encrypted Export (Finding D)
**Layers**: infrastructure, ui

Prompt for export passphrase, derive key via Argon2id, AES-256-GCM encrypt the entire JSON payload, write as `taul-export-encrypted-v1.json` with salt/nonce/tag in header.

Key files:
- MODIFY: `lib/infrastructure/export/export_service.dart` (lines 11-18 — `exportToJson`)
- NEW: `lib/infrastructure/export/encrypted_export_service.dart`
- MODIFY: `lib/ui/screens/...` (export dialog — add passphrase prompt)

**Export passphrase**: User-provided, not stored. Argon2id-derived key encrypts the whole payload. Format: `{version:2, salt_hex, nonce_hex, tag_hex, ciphertext_hex}`.

### PR4: DEK Zeroing (Finding C)
**Layers**: infrastructure, ui

Replace `_cachedDek = null` with `_cachedDek!.fill(0); _cachedDek = null` in both `CredentialProtectionController.clearCachedDek()` and `MasterPasswordNotifier.clearMasterPassword()`. Same pattern for any other `Uint8List?` holding DEK material.

Key files:
- MODIFY: `lib/ui/screens/credential_protection_controller.dart` (lines 311-313 — `clearCachedDek`)
- MODIFY: `lib/ui/providers/entry_providers.dart` (lines 93-100 — `MasterPasswordNotifier`)

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `infrastructure/security/` | New | LockoutService, encrypted export service |
| `infrastructure/database/` | Modified | SQLCipher integration, migration service |
| `infrastructure/export/` | Modified | Encrypted export support |
| `ui/screens/credential_protection_controller.dart` | Modified | Lockout integration, DEK zeroing |
| `ui/widgets/master_password_gate.dart` | Modified | Lockout integration |
| `ui/widgets/master_password_recovery_dialog.dart` | Modified | Lockout integration |
| `ui/providers/entry_providers.dart` | Modified | DEK zeroing |
| `pubspec.yaml` | Modified | New dependencies |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| SQLCipher migration loses data | Low | Verify row count + sample decryption before deleting old DB |
| Lockout bypass via app restart | Medium | Acceptable for desktop — same as macOS login lockout |
| Export passphrase forgotten | Medium | Show warning before export; format includes version for future recovery |
| Argon2id perf on export | Low | Desktop CPU is fast; 1 iteration, 64MB memory is fine |
| Dependency conflicts | Low | Test `sqflite_common_ffi` + Drift compatibility early |

## Rollback Plan

- **PR1**: Remove `LockoutService` references, revert dialog files to original retry loops
- **PR2**: Keep unencrypted DB as fallback; migration is opt-in per-user; revert `_openConnection` to `NativeDatabase(file)`
- **PR3**: Revert to plaintext `exportToJson`; encrypted exports remain readable with passphrase
- **PR4**: Revert zeroing lines to simple null assignment (no data loss)

## Dependencies

- PR1 → none (independent)
- PR2 → PR1 (MP must be required before DB encryption prompt; but PR1 is UI-only, so PR2 can technically proceed independently)
- PR3 → PR2 (export reads from DB; if DB is encrypted, export reads decrypted rows anyway — no hard dependency)
- PR4 → none (independent)

**Recommended merge order**: PR1 → PR4 → PR2 → PR3 (lockout first, zeroing quick win, then heavier infra changes)

## Success Criteria

- [ ] PR1: 5 wrong MP attempts trigger 30s lockout; 3 wrong backup code attempts trigger 60s lockout
- [ ] PR2: Existing DB migrated to encrypted; new DBs created encrypted; FTS5 content encrypted at rest
- [ ] PR3: Export prompts for passphrase; exported file is unreadable without passphrase; import with correct passphrase restores data
- [ ] PR4: `_cachedDek` and `MasterPasswordNotifier` state are zeroed before nulling
- [ ] All PRs: `dart analyze` passes, `flutter test` passes
- [ ] Each PR: under 400 changed lines
