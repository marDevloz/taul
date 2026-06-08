# Spec: Master Password Recovery

Source of truth for the master password recovery capability. Originally authored as part of the `dek-preservation` change (see `openspec/changes/archive/2026-05-25-dek-preservation/`).

---

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

## Common Requirements

### R5: Migration v3→v4
`ALTER TABLE master_password_config ADD COLUMN backup_code_data TEXT NULL`. v3 DBs continue with current behavior (new DEK on recovery).

### R6: Data format
JSON array of `{"salt_hex","ciphertext_hex","nonce_hex","tag_hex"}`, order-indexed 1:1 with `backup_code_hashes`.

### R7: No DEK leakage
DEK in memory only. Zero after use. Never logged or stored plaintext.

### R9: Service method
`master_password_recovery_service.dart` SHALL expose `unwrapDekFromBackupCode(code, codeHashes, backupCodeData) → (Uint8List dek, int codeIndex)`.

---

| Req | Scenarios |
|-----|-----------|
| R1 | 4 |
| R2 | 2 |
| R5–R7, R9 | — |

**Coverage**: Happy paths ✓, Edge cases ✓ (null data, tampered code), Errors ✓ (atomic failure, tx rollback).
