# Consolidated Spec: DEK Preservation

Full specs for modified capabilities `master-password-recovery` and `master-password-settings` — no prior specs existed.

---

## Domain: master-password-recovery

### R1: Recovery SHALL unwrap preserved DEK from backup code
Derive backup-KEK from code via Argon2id, AES-256-GCM unwrap DEK from matching `backup_code_data` entry, consume code, re-wrap DEK with new password KEK.

- **Happy path**: GIVEN valid code + populated `backup_code_data` WHEN recovery runs THEN DEK unwraps, code consumed, DEK re-wrapped, old entries decryptable.
- **Null data (backward compat)**: GIVEN `backup_code_data` IS NULL WHEN recovery THEN generate new DEK (fallback to current behavior).
- **Atomic failure**: GIVEN any step fails WHEN recovery THEN code NOT consumed, state NOT partially persisted.
- **Tampered code**: GIVEN invalid code WHEN unwrap THEN auth error, no partial data leak.

### R2: Consume code atomically with DEK re-wrap
The tx SHALL remove code from `backup_code_hashes` AND save new password + `backup_code_data` in one commit.

- **Consumed once**: GIVEN valid recovery WHEN tx commits THEN code removed, new config + wraps saved.
- **Rollback**: GIVEN DB write fails WHEN tx rolls back THEN code NOT removed, old config intact.

---

## Domain: master-password-settings

### R3: Code regen SHALL unwrap DEK via MP
Prompt for MP, derive KEK, unwrap DEK, generate new codes, re-wrap DEK, atomic save.

- **Happy path**: GIVEN correct MP WHEN regen THEN DEK unwrapped, new codes + wraps saved, old codes invalidated.
- **Wrong MP**: GIVEN incorrect MP WHEN verify fails THEN rejected, no state change.

### R4: Setup/change SHALL wrap DEK with each backup code
Iterate generated codes, derive backup-KEK from each, AES-256-GCM wrap DEK, store as JSON.

- **N wraps**: GIVEN N codes generated WHEN setup THEN DEK wrapped N times, `backup_code_data` array order-indexed to `backup_code_hashes`.
- **Round-trip verify**: GIVEN wraps done WHEN setup completes THEN verify decrypt on first code before returning.

---

## Common

### R5: Migration v3→v4
`ALTER TABLE master_password_config ADD COLUMN backup_code_data TEXT NULL`. v3 DBs continue with current behavior (new DEK on recovery).

### R6: Data format
JSON array of `{"salt_hex","ciphertext_hex","nonce_hex","tag_hex"}`, order-indexed 1:1 with `backup_code_hashes`.

### R7: No DEK leakage
DEK in memory only. Zero after use. Never logged or stored plaintext.

### R8: Settings regen triggers MP prompt
`settings_screen.dart` SHALL prompt via `credential_protection_controller` before regen.

### R9: Service method
`master_password_recovery_service.dart` SHALL expose `unwrapDekFromBackupCode(code, codeHashes, backupCodeData) → (Uint8List dek, int codeIndex)`.

---

| Req | Domain | Scenarios |
|---|---|---|
| R1 | recovery | 4 |
| R2 | recovery | 2 |
| R3 | settings | 2 |
| R4 | settings | 2 |
| R5–R9 | common | — |

**Coverage**: Happy paths ✓, Edge cases ✓ (null data, tampered code, wrong MP), Errors ✓ (atomic failure, tx rollback).
