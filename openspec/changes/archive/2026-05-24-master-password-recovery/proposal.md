# Proposal: Master Password Recovery

Add offline recovery (backup codes + hint) and move management to Settings for transparent credential protection.

## Intent

Current flow: MP prompt at every credential creation, no recovery. This adds **offline self-recovery** (no email/API) and Settings management.

**Success**: Manage MP in Settings, recover via codes or hint, create protected credentials without re-entering MP.

## Scope

| In | Out |
|----|-----|
| Schema v2→v3: +`password_hint`, +`backup_code_hashes` | Email/password reset |
| 10 codes, Argon2id-hashed, single-use | Biometric unlock |
| Hint stored + shown at reveal prompt | Cloud sync of codes |
| Settings: create/change/hint/regenerate codes | Password strength meter |
| Transparent encrypt if configured; setup if not | |

## Capabilities

- **New** `master-password-settings`: Settings UI for create/change/hint/backup-codes
- **New** `master-password-recovery`: Offline recovery via hashed single-use codes + hint

## Approach

| Layer | What |
|-------|------|
| **Infrastructure** | +2 cols on `master_password_config`, v3 migration. Extend store CRUD. +`generateBackupCodes()` — 10 random → Argon2id hash each → `[plain, hashes]` |
| **Domain** | Verify code (hash-match → consume). Change MP (passwords use independent AES keys — no re-encrypt) |
| **UI** | Settings screen. Refactor controller: no config → setup dialog with codes + hint; config exists → encrypt silently. Hint + recover link in reveal dialog |

## Affected Areas

| Area | Impact |
|------|--------|
| `.../master_password_config_table.dart` | +2 cols |
| `.../app_database.dart` | Schema v3 |
| `.../master_password_store.dart` | CRUD hint + codes |
| `.../entry_auth_service.dart` | +generateBackupCodes() |
| `.../entry_providers.dart` | +hint +recovery providers |
| `.../credential_protection_controller.dart` | Transparent flow + setup |
| `.../entry_detail_view.dart` | Hint + recovery at reveal |
| New: settings screen + provider | Settings management |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Code consumed but DB write fails | Low | Tx: verify+delete atomically |
| User loses both password AND codes | Medium | Accept (no network). Warn at setup |
| v3 migration on v2 DB | Low | Nullable cols. Safe ALTER TABLE |

## Rollback Plan

1. Revert schema to v2 (DROP COLUMN safe on null).
2. Revert table, migration, remove new screens/providers.
3. Only hint + codes lost (no secrets affected).

## Dependencies

None. All crypto in project (Argon2id, `Random.secure()`).

## Success Criteria

- [ ] v2→v3 migration clean with existing data
- [ ] 10 codes generated, hashed, each consumed once
- [ ] Hint stored + displayed at reveal prompt
- [ ] Settings: create, change, hint, regenerate work
- [ ] No MP prompt when already configured (transparent encrypt)
- [ ] All existing tests pass; new tests cover recovery
