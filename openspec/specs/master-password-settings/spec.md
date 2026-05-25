# Spec: Master Password Settings

Source of truth for the master password settings capability — setup, change, and code regeneration. Originally authored as part of the `dek-preservation` change (see `openspec/changes/archive/2026-05-25-dek-preservation/`).

---

### R3: Code regen SHALL unwrap DEK via MP
Prompt for MP, derive KEK, unwrap DEK, generate new codes, re-wrap DEK, atomic save.

- **Happy path**: GIVEN correct MP WHEN regen THEN DEK unwrapped, new codes + wraps saved, old codes invalidated.
- **Wrong MP**: GIVEN incorrect MP WHEN verify fails THEN rejected, no state change.

### R4: Setup/change SHALL wrap DEK with each backup code
Iterate generated codes, derive backup-KEK from each, AES-256-GCM wrap DEK, store as JSON.

- **N wraps**: GIVEN N codes generated WHEN setup THEN DEK wrapped N times, `backup_code_data` array order-indexed to `backup_code_hashes`.
- **Round-trip verify**: GIVEN wraps done WHEN setup completes THEN verify decrypt on first code before returning.

---

## Common Requirements

### R5: Migration v3→v4
`ALTER TABLE master_password_config ADD COLUMN backup_code_data TEXT NULL`. v3 DBs continue with current behavior (new DEK on recovery).

### R6: Data format
JSON array of `{"salt_hex","ciphertext_hex","nonce_hex","tag_hex"}`, order-indexed 1:1 with `backup_code_hashes`.

### R7: No DEK leakage
DEK in memory only. Zero after use. Never logged or stored plaintext.

### R8: Settings regen triggers MP prompt
`settings_screen.dart` SHALL prompt via `credential_protection_controller` before regen.

---

| Req | Scenarios |
|-----|-----------|
| R3 | 2 |
| R4 | 2 |
| R5–R8 | — |

**Coverage**: Happy paths ✓, Edge cases ✓ (wrong MP, round-trip verify).
