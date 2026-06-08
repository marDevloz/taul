# Proposal: DEK Preservation During Recovery

## Intent

During backup code recovery, a new DEK (Data Encryption Key) is generated — all entries encrypted with the old DEK become unreachable. This change preserves the DEK by wrapping it with each backup code during setup, enabling recovery without data loss.

## Scope

### In Scope
- Schema v3→v4: new `backup_code_data` TEXT column in `master_password_config`
- Setup: wrap DEK with each backup code, store per-code wraps
- Recovery: unwrap preserved DEK from code, re-wrap with new KEK
- Code regeneration: prompt MP to unwrap DEK, re-wrap with new codes
- Backward compat: old DBs without column keep current behavior (new DEK)

### Out of Scope
- Re-encrypting existing entries (unnecessary — DEK is preserved)
- Cloud sync of backup codes
- UI redesign or new screens
- Multiple DEKs or key rotation

## Capabilities

### Modified Capabilities
- `master-password-recovery`: recovery now preserves DEK instead of generating new one
- `master-password-settings`: code regeneration now requires MP prompt to unwrap DEK

## Approach

| Phase | What |
|-------|------|
| **Setup** | After wrapping DEK with KEK, iterate backup codes → Argon2id derive backup-KEK from each → AES-256-GCM wrap DEK → store as `backup_code_data` JSON |
| **Recovery** | Verify code → derive backup-KEK → unwrap DEK → consume code → new MP + new salt → re-wrap DEK with new KEK → save new wraps + hashes |
| **Regen** | Prompt MP → derive KEK from password → unwrap DEK → wrap with new backup codes → save new `backup_code_data` + new `backup_code_hashes` |

### Data format

`backup_code_data`: JSON array of objects, order-indexed to match `backup_code_hashes`:

```json
[
  {"salt_hex":"...","ciphertext_hex":"...","nonce_hex":"...","tag_hex":"..."}
]
```

Each entry is an AES-256-GCM wrapped DEK, encrypted with a backup-KEK derived from the corresponding backup code via Argon2id (same params as MP hashing).

## Affected Areas

| Area | Impact |
|------|--------|
| `.../database/master_password_config_table.dart` | +`backup_code_data` col |
| `.../database/app_database.dart` | Schema v4, migration v3→v4 branch |
| `.../security/master_password_store.dart` | +read/write `backup_code_data` |
| `.../security/entry_auth_service.dart` | No changes (wrap/unwrap already generic) |
| `.../services/master_password_recovery_service.dart` | +`unwrapDekFromBackupCode()` |
| `.../screens/credential_protection_controller.dart` | Wrap DEK with codes during setup |
| `.../screens/master_password_setup_dialog.dart` | Wrap DEK with codes during setup/change |
| `.../widgets/master_password_recovery_dialog.dart` | Unwrap DEK, re-wrap with new KEK |
| `.../screens/settings_screen.dart` | Regen: prompt MP, re-wrap DEK |
| `test/` | Unit + integration for new paths |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Code consumed but backup_code_data write fails | Low | Atomic tx: unwrap → consume → save in single tx |
| Backup code wrap corrupt (round-trip fails) | Low | Verify decrypt round-trip at setup time |
| v4 migration on v3 DB with existing data | Low | Nullable col, safe ALTER TABLE ADD COLUMN |
| Old backup_code_data orphaned after regen | Low | Cleared atomically with new hashes via `saveFull()` |
| User loses MP + backup codes + has no backup | Low | Already warned at setup (existing UX) |

## Rollback Plan

1. Revert schema to v3 — `DROP COLUMN backup_code_data` (safe, nullable).
2. Revert store methods, recovery service, dialog changes.
3. Old DBs unaffected — column never exists for them.
4. Users with v4 data: codes become recovery-only (no DEK preservation, fallback to current behavior — generates new DEK with guidance text).

## Dependencies

None. Uses existing `wrapStorageKey(dek, kek)` / `unwrapStorageKey(payload, kek)` + `deriveMasterKey(code, salt)` — all already in `EntryAuthService`.

## Success Criteria

- [ ] Setup: DEK correctly wrapped with each backup code, stored as `backup_code_data`
- [ ] Recovery: preserved DEK unwrapped from code, re-wrapped with new KEK — old entries decryptable
- [ ] Code regen: MP prompt shown, DEK unwrapped and re-wrapped with new codes atomically
- [ ] v3→v4 migration: clean on v3 data, column defaults to NULL
- [ ] Backward compat: old DBs (no `backup_code_data`) generate new DEK on recovery (current behavior)
- [ ] All existing tests pass; new tests cover wrap/unwrap round-trip and migration
