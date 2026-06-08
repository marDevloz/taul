# Tasks: Security Remediation — PR #2 (SQLite Encryption) & PR #3 (Encrypted Export)

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | PR #2: ~120 · PR #3: ~175 · Total: ~295 |
| 400-line budget risk | Low |
| Chained PRs recommended | Yes |
| Suggested split | PR #2 → PR #3 (stacked to main) |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: Low

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | SQLite encryption with migration | PR #2 | Base: main. Foundational — PR #3 depends on crypto patterns |
| 2 | Passphrase-protected export/import | PR #3 | Base: main (independent, but logically after PR #2) |

---

## PR #2: SQLite Encryption (Finding A)

### Phase 1: Dependency

- [ ] 2.1.1 Upgrade `sqlite3` from `^2.7.4` to `^3.0.0` in `pubspec.yaml` — enables SQLite3MultipleCiphers build hook (est. ~3 lines)

### Phase 2: Infrastructure

- [ ] 2.2.1 Add `static String? _dekHex` field and `static void setEncryptionKey(Uint8List dek)` method to `AppDatabase` class in `app_database.dart` — stores hex DEK for PRAGMA key (est. ~10 lines)
- [ ] 2.2.2 Rewrite `_openConnection()` in `app_database.dart` to use `NativeDatabase.createInBackground(encryptedFile, setup: ...)` with `PRAGMA key` — new file path `taul.db.enc` (est. ~20 lines)
- [ ] 2.2.3 Create `lib/infrastructure/database/db_encryption_service.dart` — `migrateIfNeeded()` detects unencrypted DB, runs `sqlcipher_export` + ATTACH pattern, verifies row count, transfers `user_version`, atomic swap via rename, deletes old file. Idempotent on retry (est. ~80 lines)

### Phase 3: Integration

- [ ] 2.3.1 In `_getOrSetupMasterKey()` of `credential_protection_controller.dart`, after unwrapping DEK (line ~188) and after setting up new DEK (line ~255), call `AppDatabase.setEncryptionKey(dek)` — ensures DEK is set before DB connection resolves (est. ~6 lines)

### Phase 4: Testing

- [ ] 2.4.1 Write unit test for `DbEncryptionService.migrateIfNeeded` — create in-memory unencrypted DB with data, migrate, verify data intact and `user_version` preserved (est. ~40 lines)

**PR #2 total estimate**: ~120 lines changed

---

## PR #3: Encrypted Export (Finding D)

### Phase 1: Infrastructure

- [ ] 3.1.1 Create `lib/infrastructure/export/encrypted_export_service.dart` — `EncryptedExportService` class with `encryptExport(plaintextJson, passphrase)` and `decryptExport(encryptedJson, passphrase)` methods. Reuses `EntryAuthService` for Argon2id + AES-256-GCM. Returns `{version:2, salt_hex, nonce_hex, tag_hex, ciphertext_hex}` (est. ~70 lines)
- [ ] 3.1.2 Add `encryptedExportServiceProvider` to `entry_providers.dart` — `Provider<EncryptedExportService>` injecting `entryAuthServiceProvider` (est. ~5 lines)

### Phase 2: Integration

- [ ] 3.2.1 Modify `export_service.dart` — add `exportToJsonEncrypted(entries, passphrase)` method that delegates to `EncryptedExportService.encryptExport()` (est. ~15 lines)
- [ ] 3.2.2 Modify `import_service.dart` — add `importFromJsonString(jsonString, {passphrase})` overload. Detect `version:2` in wrapper, if encrypted and passphrase provided, delegate to `EncryptedExportService.decryptExport()` before parsing entries. Backward-compatible with v1 (est. ~30 lines)

### Phase 3: UI

- [ ] 3.3.1 In `settings_screen.dart` `_exportData()`: after disclaimer dialog, show passphrase dialog (two fields: passphrase + confirm, min 8 chars, mismatch error). Pass passphrase to `exportToJsonEncrypted()`. Update disclaimer text to mention encryption (est. ~50 lines)
- [ ] 3.3.2 In `settings_screen.dart` `_importData()`: after reading file JSON, detect `version:2`. If encrypted, show single passphrase field. On AES-GCM tag fail, show "Contraseña incorrecta". Delegate decryption to import service (est. ~40 lines)

### Phase 4: Testing

- [ ] 3.4.1 Write unit tests for `EncryptedExportService` — round-trip encrypt/decrypt, wrong passphrase rejection, same passphrase different salts produce different ciphertext (est. ~35 lines)
- [ ] 3.4.2 Write unit test for v1 import backward compatibility — parse plaintext JSON, verify entries imported (est. ~15 lines)

**PR #3 total estimate**: ~175 lines changed

---

## Risk Items

| Risk | Impact | Mitigation |
|------|--------|------------|
| SQLite3MultipleCiphers build hook requires additional platform config | Medium | Test build on all target platforms (Android, iOS, Linux, Windows) early in PR #2 |
| Mid-migration crash leaves DB in inconsistent state | Low | Idempotent retry: encrypted tmp exists + encrypted final missing → retry migration |
| Argon2id memory pressure on low-end devices | Low | Desktop app — 64MB is fine; monitor if mobile target added |
| Passphrase dialog UX confusion (export vs import) | Low | Clear Spanish copy: "Contraseña de exportación" / "Contraseña de importación" |
