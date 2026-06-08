# Design: DEK Preservation During Recovery

## Technical Approach

Add nullable `backup_code_data` TEXT column (schema v4). During MP setup, for each backup code derive a per-code backup-KEK via Argon2id (unique 16B salt), AES-256-GCM wrap the DEK, store as JSON array at matching index. During recovery, derive backup-KEK from entered code + stored salt, unwrap preserved DEK, re-wrap with new KEK. NULL column = generate new DEK (existing behavior). Code regen requires MP prompt to unwrap DEK before re-wrapping with new codes.

## Architecture Decisions

| # | Decision | Options | Chosen | Rationale |
|---|----------|---------|--------|-----------|
| A1 | backup-KEK salt | (a) reuse hash salt (8B), (b) new 16B | (b) New per-code 16B | Separate derivation avoids salt reuse; 16B matches Argon2id nonce size |
| A2 | `backup_code_data` fields | (a) spec R6: 4 fields, (b) task: 5 fields incl `hash` | (b) 5-field schema | `hash` enables self-contained validation; redundant with `backup_code_hashes` but harmless |
| A3 | Atomic consume | (a) two separate calls, (b) single method | (b) `consumeBackupCodeAtIndexAndData` | Eliminates partial-state risk; mirrors existing pattern |
| A4 | Unwrap location | (a) EntryAuthService, (b) RecoveryService | (b) RecoveryService | RecoveryService already holds authService; dialog stays thin |
| A5 | Regen DEK access | (a) inline in settings, (b) controller method | (b) Controller.requireMasterKey() | Avoids duplicating MP verify+unwrap across screens |

## Data Model

### JSON schema (per entry, order-indexed 1:1 with `backup_code_hashes`)

```json
{
  "salt": "16 bytes as hex",
  "hash": "Argon2id output hex",
  "dek_cipher": "AES-256-GCM ciphertext hex",
  "dek_nonce": "12 bytes as hex",
  "dek_tag": "16 bytes as hex"
}
```

### Dart model

```dart
class BackupCodeEntry {
  final String saltHex;
  final String hashHex;
  final String dekCipherHex;
  final String dekNonceHex;
  final String dekTagHex;
  
  // fromJson / toJson using dart:convert
}
```

### DB migration (app_database.dart)

```dart
@override int get schemaVersion => 4;

// in onUpgrade:
if (from < 4) {
  await m.addColumn(
    masterPasswordConfig,
    masterPasswordConfig.backupCodeData,
  );
}
```

## File Changes

| File | Action | What |
|------|--------|------|
| `.../master_password_config_table.dart` | Modify | +`backupCodeData` nullable text column |
| `.../app_database.dart` | Modify | schemaVersion 4, migration branch `from < 4` |
| `.../master_password_store.dart` | Modify | +`BackupCodeEntry` model, +read/write/consume for backup_code_data |
| `.../master_password_recovery_service.dart` | Modify | +`unwrapDekFromBackupCode()` method |
| `.../credential_protection_controller.dart` | Modify | Wrap DEK per code in setup; expose `requireMasterKey()` for regen |
| `.../master_password_setup_dialog.dart` | Modify | Pass `backupCodeDataJson` to `saveFull` |
| `.../master_password_recovery_dialog.dart` | Modify | Unwrap preserved DEK before consuming code |
| `.../settings_screen.dart` | Modify | Prompt MP via controller, re-wrap DEK with new codes |

## Store API

### MasterPasswordStore new/modified methods

```dart
/// Reads backup_code_data JSON → parsed list or null.
Future<List<BackupCodeEntry>?> readBackupCodeData();

/// Atomically removes hash at index AND corresponding data entry.
Future<bool> consumeBackupCodeAtIndexAndData(int index);

/// Modified: adds backupCodeDataJson parameter.
Future<void> saveFull({
  ..., // existing params
  String? backupCodeDataJson,  // NEW
});

/// Modified: MasterPasswordFullConfig gains backupCodeData field.
class MasterPasswordFullConfig {
  ...
  final List<BackupCodeEntry>? backupCodeData;  // NEW
}
```

## Recovery Service API

```dart
/// Finds matching code index, derives backup-KEK, unwraps DEK.
/// Returns (dek, codeIndex) or throws.
Future<({Uint8List dek, int codeIndex})> unwrapDekFromBackupCode({
  required String code,
  required List<String> codeHashes,
  required List<BackupCodeEntry> backupCodeData,
});
```

## Flows

### Setup (controller + dialog)

```
1. Generate DEK → salt → hash → KEK → wrap DEK with KEK
2. Generate backup codes → codesResult
3. FOR each code:
   a. Derive backup-KEK: Argon2id(code, unique 16B salt)
   b. AES-256-GCM wrap DEK with backup-KEK → BackupCodeEntry
4. Build backup_code_data JSON array from entries
5. Round-trip verify: unwrap first entry, assert DEK matches
6. store.saveFull(hash, salt, hint, codesJson, wrapped, backupCodeDataJson)
```

### Recovery (dialog)

```
1. store.readFull() → hashes + backup_code_data
2. recoveryService.verifyBackupCode(code, hashes) → index
3. Read backup_code_data[index] → entry (store in memory)
4. store.consumeBackupCodeAtIndexAndData(index) — atomic
5. User enters new MP
6. Derive backup-KEK: Argon2id(code, hexToBytes(entry.saltHex))
7. authService.unwrapStorageKey(entry.payload, backupKEK) → DEK
8. Derive new KEK from new MP → wrap DEK with it
9. Generate new backup codes → wrap DEK per code → build new data
10. store.saveFull(newHash, newSalt, newCodesJson, newKekWrap, newData)
```

### Code regeneration (settings)

```
1. Confirmation dialog (existing)
2. controller.requireMasterKey(context) → prompts MP → unwraps DEK
3. Generate new codes → codesResult
4. FOR each new code: derive backup-KEK → wrap DEK → build data
5. store.saveFull(...) — atomically saves new hashes + new data
6. Clear cached DEK
```

## Testing Strategy

| Layer | What | How |
|-------|------|-----|
| Unit | BackupCodeEntry JSON round-trip | Parse/serialize, verify all 5 fields |
| Unit | unwrapDekFromBackupCode | Mock authService, verify derive+unwrap called with correct params |
| Unit | consumeBackupCodeAtIndexAndData | In-memory SQLite; verify both arrays shrink atomically |
| Unit | Round-trip wrap/unwrap | Real crypto: setup codes → wrap DEK → unwrap each → eq |
| Integration | Recovery preserves DEK | Full flow: setup w/ codes → recovery → old entries decryptable |
| Integration | v3 backward compat | DB without column → new DEK generated (current behavior) |
| Widget | Settings regen shows MP prompt | Fake auth + store, verify dialog appears |
| Widget | Recovery dialog unwraps DEK | Fake auth + store with backup_code_data, verify success |

## Migration / Rollout

`ALTER TABLE ADD COLUMN` is safe on existing v3 DBs — column defaults to NULL, all code paths check for null. Rollback: revert schema to v3 (`DROP COLUMN` safe on nullable), revert code changes. No data migration needed.

## Open Questions

None.
