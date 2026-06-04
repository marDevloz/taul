# Design: Master Password Recovery

Add offline recovery (backup codes + hint) and move management to Settings so users can create protected credentials without repeated MP prompts and recover access without network.

## Quick path

1. **Schema** v2→v3: +2 nullable columns (`password_hint`, `backup_code_hashes`, `encrypted_storage_key`)
2. **Crypto**: introduce a wrapping key pattern (KEK/DEK) so changing MP never requires re-encrypting entries
3. **Infrastructure**: extend `MasterPasswordStore` with hint/codes CRUD, atomic consume; add `generateBackupCodes()` to `EntryAuthService`
4. **Domain**: new `MasterPasswordRecoveryService` — verify code, consume atomically, change MP, validate hint
5. **UI**: Settings screen + providers; refactored `CredentialProtectionController` for transparent flow; modified reveal dialog with hint + recovery link

---

## 1. Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                         UI (Flutter)                          │
│                                                               │
│  SettingsScreen      RecoveryDialog     Modified RevealDialog │
│  SetupDialog         ChangeMPDialog     settingsProvider      │
│  recoveryProvider    configProvider     CredentialProtection  │
│                                          Controller (refact)  │
├──────────────────────────────────────────────────────────────┤
│                     Domain (Dart only)                        │
│                                                               │
│  MasterPasswordRecoveryService                                 │
│   ├─ verifyBackupCode(code) → VerificationResult              │
│   ├─ consumeBackupCode(code) → ConsumptionResult              │
│   ├─ changeMasterPassword(old, new) → void                    │
│   ├─ setupMasterPassword(password, hint) → BackupCodeSet      │
│   └─ validateHint(hint) → String?                             │
├──────────────────────────────────────────────────────────────┤
│                    Infrastructure                              │
│                                                               │
│  MasterPasswordStore (extended)  EntryAuthService (+genCodes) │
│  master_password_config_table (+3 cols)                       │
│  app_database.dart (v2→v3 migration)                          │
└──────────────────────────────────────────────────────────────┘
```

### Layer Boundaries

| Layer | Owns | Doesn't own |
|-------|------|-------------|
| **Domain** | Recovery logic, hint validation, MP change orchestration, code verification | DB, crypto primitives, UI |
| **Infrastructure** | Drift migrations, `MasterPasswordStore` CRUD, `generateBackupCodes()`, DB transactions | Business rules, UI state |
| **UI** | Settings screen, dialogs, providers, refactored controller | DB writes, crypto keys |

---

## 2. Key Architectural Decision: Wrapping Key (KEK/DEK)

### Problem

The proposal states "no re-encrypt needed when changing MP." But the current codebase derives the AES-256-GCM key **directly** from the master password:

```dart
// Current: masterKey is the AES key
masterKey = Argon2id.deriveKey(password, globalSalt)
AES-256-GCM.encrypt(secret, key=masterKey, nonce=entryNonce)
```

Changing the MP produces a **different** `masterKey`, making all existing ciphertexts undecryptable.

### Solution: Key Encryption Key / Data Encryption Key

Introduce a **wrapping key** (Storage Key / DEK) that is generated once and encrypted with the MP-derived key:

```
┌────────────────────────────────────────────┐
│           Master Password                   │
│                 ↓                           │
│    Argon2id(password, salt)                 │
│                 ↓                           │
│         Master Key (KEK) ─────┐             │
│                               │ encrypt     │
│         Storage Key (DEK) ────┘             │
│         (random 32 bytes)                   │
│                               │             │
│         ┌─────────────────────┘             │
│         ↓                                   │
│   encryptedStorageKey (stored in DB)        │
│                                               │
│   Per-entry:                                  │
│   AES-256-GCM.encrypt(secret, key=DEK)       │
└──────────────────────────────────────────────┘
```

### Flows

| Operation | What happens |
|-----------|-------------|
| **Setup MP** | Generate DEK (random) → derive KEK → encrypt DEK with KEK → store `encryptedStorageKey` |
| **Verify MP (login)** | Derive KEK → decrypt `encryptedStorageKey` → cache DEK in memory |
| **Encrypt entry** | Use cached DEK directly (no MP derivation) |
| **Decrypt entry** | Use cached DEK directly |
| **Change MP** | Decrypt DEK with old-KEK → derive new-KEK → encrypt DEK with new-KEK → store → **no entry changes** |
| **Session end** | Clear cached DEK |

### Tradeoffs

| Factor | Wrapping Key | Direct Key (re-encrypt) |
|--------|-------------|------------------------|
| MP change latency | Instant (1 encrypt) | O(n) where n = protected entries |
| Code complexity | Slightly higher setup | Lower |
| Security | Equivalent (DEK never in plaintext on disk) | Equivalent |
| Memory | Stores DEK (32 bytes) + KEK (transient) | Stores KEK only |

**Chosen: Wrapping key.** Matches proposal intent, instant MP changes, zero data migration risk.

---

## 3. Database Migration

### v2 → v3 SQL

```sql
ALTER TABLE master_password_config
  ADD COLUMN password_hint TEXT;

ALTER TABLE master_password_config
  ADD COLUMN backup_code_hashes TEXT;

ALTER TABLE master_password_config
  ADD COLUMN encrypted_storage_key TEXT;
```

All columns are **nullable** — existing v2 rows migrate without data loss.

### Updated Drift Table

```dart
class MasterPasswordConfig extends Table {
  IntColumn get id => integer().clientDefault(() => 1)();
  TextColumn get passwordHashArgon2 => text()();
  TextColumn get saltHex => text()();
  TextColumn? get passwordHint => text().nullable()();
  TextColumn? get backupCodeHashes => text().nullable()();
  TextColumn? get encryptedStorageKey => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

### Migration Code

```dart
// In AppDatabase

@override
int get schemaVersion => 3;

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (m) async {
    await m.createAll();
    await _createFtsTable();
  },
  onUpgrade: (m, from, to) async {
    if (from < 2) {
      await m.addColumn(entries, entries.requiresAuth);
      await m.addColumn(entries, entries.encryptedSecret);
      await m.addColumn(entries, entries.cipherNonce);
      await m.addColumn(entries, entries.cipherTag);
      await m.createTable(masterPasswordConfig);
    }
    if (from < 3) {
      await m.addColumn(
        masterPasswordConfig, masterPasswordConfig.passwordHint,
      );
      await m.addColumn(
        masterPasswordConfig, masterPasswordConfig.backupCodeHashes,
      );
      await m.addColumn(
        masterPasswordConfig, masterPasswordConfig.encryptedStorageKey,
      );
    }
  },
  beforeOpen: (_) async {
    await _createFtsTable();
  },
);
```

### Backup Code JSON Schema

```json
{
  "version": 1,
  "codes": [
    {
      "hash": "a1b2c3...",   // Argon2id hex output (64 chars)
      "salt": "d4e5f6..."    // Per-code random salt (32 hex chars)
    },
    ...
  ]
}
```

Stored as TEXT in `backup_code_hashes`. Each code gets its own Argon2id salt — prevents rainbow tables and batch cracking.

---

## 4. Component Architecture

### 4.1 Modified Files

| File | Change |
|------|--------|
| `.../master_password_config_table.dart` | +3 columns: `passwordHint`, `backupCodeHashes`, `encryptedStorageKey` |
| `.../app_database.dart` | Schema v3, migration for v2→v3 |
| `.../master_password_store.dart` | +`readFull()`, `saveFull()`, `readHint()`, `saveHint()`, `readBackupCodes()`, `consumeBackupCode(index)`, `readEncryptedStorageKey()`, `saveEncryptedStorageKey()` |
| `.../entry_auth_service.dart` | +`generateBackupCodes()` returns `BackupCodeSet` |
| `.../credential_protection_controller.dart` | Refactored: uses wrapping key; transparent encrypt when DEK cached; setup includes hint + codes |
| `.../entry_providers.dart` | +`masterPasswordConfigProvider`, `masterPasswordHintProvider`, `masterPasswordRecoveryServiceProvider` |
| `.../entry_detail_view.dart` | Reveal dialog shows hint + recovery link on wrong password |

### 4.2 New Files

| File | Layer | Purpose |
|------|-------|---------|
| `lib/domain/services/master_password_recovery_service.dart` | **Domain** | Verify code, consume atomically, change MP, setup with hint + codes |
| `lib/ui/screens/settings_screen.dart` | **UI** | Settings entry point with MP management section |
| `lib/ui/widgets/master_password_setup_dialog.dart` | **UI** | First-time setup: password + confirm + hint + codes display |
| `lib/ui/widgets/master_password_recovery_dialog.dart` | **UI** | Enter backup code, verify, set new MP |
| `lib/ui/widgets/master_password_change_dialog.dart` | **UI** | Change MP: current → new → confirm |
| `lib/ui/providers/settings_providers.dart` | **UI** | `settingsProvider`, `backupCodesProvider` |

### 4.3 MasterPasswordRecoveryService (Domain)

```dart
class VerificationResult {
  final bool success;
  final int? matchedIndex;   // null if no match
  final String? errorMessage;
}

class ConsumptionResult {
  final bool success;
  final int remainingCodes;
  final String? errorMessage;
}

class SetupResult {
  final BackupCodeSet codes;
  final String message; // "Guardá estos códigos..."
}

class MasterPasswordRecoveryService {
  const MasterPasswordRecoveryService({
    required EntryAuthService authService,
    required MasterPasswordStore store,
    required Ref ref,  // for invalidating providers
  });

  /// Setup: generate DEK → encrypt with KEK → save all.
  /// Returns 10 plain backup codes for the user to save.
  Future<SetupResult> setupMasterPassword({
    required String password,
    String? hint,
  });

  /// Verify a backup code against stored hashes.
  Future<VerificationResult> verifyBackupCode(String code);

  /// Atomic: verify + consume in same DB transaction.
  /// On failure (DB error), code is NOT consumed — safe to retry.
  Future<ConsumptionResult> consumeBackupCode(String code);

  /// Change MP: decrypt DEK with old-KEK → derive new-KEK → encrypt DEK.
  /// No entry re-encryption needed.
  Future<void> changeMasterPassword({
    required String currentPassword,
    required String newPassword,
    String? newHint,
  });

  /// Regenerate backup codes (old codes invalidated).
  Future<BackupCodeSet> regenerateBackupCodes();

  static String? validateHint(String? hint) { /* max 200 chars */ }
}
```

### 4.4 EntryAuthService Extension

```dart
class BackupCodeSet {
  final List<String> plainCodes;    // "X8kM-2pRq" — shown to user, ephemeral
  final List<Map<String, String>> hashedCodes; // [{hash, salt}, ...]
}

class EntryAuthService {
  // ... existing methods ...

  /// Generates 10 backup codes using Random.secure().
  /// Each code: 8 chars, alphanumeric, formatted as XXXX-XXXX.
  /// Each code is individually salted and hashed with Argon2id.
  Future<BackupCodeSet> generateBackupCodes();

  /// Encrypts the storage key (DEK) with the master key (KEK).
  Future<String> encryptStorageKey({
    required Uint8List storageKey,
    required Uint8List masterKey,
  });

  /// Decrypts the storage key (DEK) using the master key (KEK).
  Future<Uint8List> decryptStorageKey({
    required String encryptedStorageKeyHex,
    required Uint8List masterKey,
  });
}
```

### 4.5 MasterPasswordStore Extensions

```dart
class MasterPasswordFullConfig {
  final String hashHex;
  final String saltHex;
  final String? hint;
  final List<Map<String, String>>? backupCodeHashes;
  final String? encryptedStorageKey;
}

class MasterPasswordStore {
  // ... existing read(), save() ...

  Future<MasterPasswordFullConfig?> readFull();

  /// Atomic: remove code at [index] from backup_code_hashes JSON array.
  /// Runs in a transaction: parse → splice → serialize → UPDATE.
  /// Returns true if DB write succeeded.
  Future<bool> consumeBackupCodeAtIndex(int index);

  // Individual accessors
  Future<String?> readHint();
  Future<void> saveHint(String hint);
  Future<String?> readEncryptedStorageKey();
  Future<void> saveEncryptedStorageKey(String hex);
  Future<List<Map<String, String>>?> readBackupCodeHashes();
  Future<void> saveBackupCodeHashes(String json);
}
```

### 4.6 CredentialProtectionController Refactored

```dart
class CredentialProtectionController {
  /// Returns whether a setup is needed (no KEK/DEK exists).
  Future<bool> isConfigured();

  /// If DEK is cached → encrypt silently.
  /// If KEK exists but no DEK → prompt for password → decrypt DEK → cache.
  /// If nothing exists → show setup dialog with hint + codes.
  Future<ProtectionResult?> resolveProtection({
    required BuildContext context,
    required bool protectEntry,
    ...
  });

  /// New: get hint for display (returns null if none).
  Future<String?> getHint();

  /// New: get remaining code count.
  Future<int> getRemainingCodeCount();
}
```

### 4.7 Modified Reveal Flow (entry_detail_view.dart)

```dart
// In _revealProtectedSecret():

Future<void> _revealProtectedSecret() async {
  // 1. Try cached DEK → decrypt directly
  var dek = ref.read(masterPasswordProvider.notifier).cachedKey;
  if (dek != null) {
    _showDecryptedSecret(dek);
    return;
  }

  // 2. Prompt for MP
  final password = await _askForPassword(showHint: true); // <-- NEW: hint shown
  if (password == null) return;

  final store = ref.read(masterPasswordStoreProvider);
  final config = await store.readFull();
  final isValid = await auth.verifyMasterPassword(...);

  if (!isValid) {
    // 3. Wrong MP — show recovery option
    final recoveryChosen = await _showRecoveryOption();
    if (recoveryChosen) {
      await _openRecoveryDialog();
    }
    return;
  }

  // 4. Valid MP: decrypt DEK, cache it, decrypt entry
  final kek = await auth.deriveMasterKey(password: password, salt: salt);
  final dek = await auth.decryptStorageKey(
    encryptedStorageKeyHex: config!.encryptedStorageKey!,
    masterKey: kek,
  );
  ref.read(masterPasswordProvider.notifier).setMasterPassword(dek);
  _showDecryptedSecret(dek);
}
```

### 4.8 New Providers

```dart
// Domain service
final masterPasswordRecoveryServiceProvider =
    Provider<MasterPasswordRecoveryService>((ref) {
  return MasterPasswordRecoveryService(
    authService: ref.watch(entryAuthServiceProvider),
    store: ref.watch(masterPasswordStoreProvider),
    ref: ref,
  );
});

// Full config (triggers rebuild on hint/code changes)
final masterPasswordConfigProvider =
    FutureProvider<MasterPasswordFullConfig?>((ref) {
  return ref.watch(masterPasswordStoreProvider).readFull();
});

// Derived: hint
final masterPasswordHintProvider = FutureProvider<String?>((ref) {
  final config = ref.watch(masterPasswordConfigProvider).valueOrNull;
  return config?.hint;
});

// Settings state
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

// Ephemeral: plain codes after generation (NEVER persisted)
final generatedCodesProvider = StateProvider<List<String>?>((ref) => null);
```

### 4.9 Settings Screen Structure

```
SettingsScreen
├── MP Status Section
│   ├─ "Master Password: Configurada" (if set)
│   ├─ Hint display (if set)
│   ├─ Remaining backup codes count
│   └─ "Configurar" (if not set)
│
├── Actions Section (when configured)
│   ├─ "Cambiar Master Password" → ChangeMPDialog
│   ├─ "Cambiar Hint" → text field dialog
│   ├─ "Regenerar Códigos de Recuperación" → confirm → show new codes
│   └─ "Eliminar Master Password" → confirm → remove config (decrypts nothing)
│
└── Danger Zone
    └─ "Eliminar MP" → warning: protected entries become unrecoverable
```

---

## 5. State Machine (Riverpod)

```
                    ┌──────────────────────┐
                    │  masterPasswordProvider │
                    │  (StateNotifier<Uint8List?>) │
                    └──────────────────────┘
                            │
         null ────setup────► DEK (after setup)
         null ────verify───► DEK (decrypt encryptedStorageKey)
         DEK ────change MP─► null (cache cleared)
         DEK ────logout────► null (manual or session end)

                    ┌────────────────────────┐
                    │  masterPasswordConfigProvider │
                    │  (FutureProvider)              │
                    └────────────────────────┘
                            │
          invalidated on ───► create / change / consume / regenerate

                    ┌────────────────────────┐
                    │  settingsProvider              │
                    │  (StateNotifier<SettingsState>) │
                    └────────────────────────┘
                            │
  idle ──setup/change──────► loading ──done──► idle
  idle ──regenerate────────► loading ──done──► idle (show codes)
  idle ──delete────────────► confirming ──done──► idle
  any ──error──────────────► error ──dismiss──► idle
```

### masterPasswordProvider Caching Behavior

| Event | Action |
|-------|--------|
| App cold start | `null` (no DEK cached) |
| User enters MP (verify) | Decrypt `encryptedStorageKey` → cache DEK |
| User sets up MP first time | Generate DEK → encrypt with KEK → cache DEK |
| User changes MP | Decrypt DEK with old KEK → encrypt with new KEK → **clear DEK from cache** (re-auth needed) |
| Reveal with cached DEK | Use DEK directly — no MP prompt |
| Create credential with cached DEK | Use DEK directly — no MP prompt |
| User navigates away / timeout | Keep DEK in cache (session lifetime — TBD: add session timeout?) |
| App lifecycle: background → foreground | Keep DEK (no auto-clear for v1) |
| Manual "Cerrar sesión" | Clear DEK → `null` |

---

## 6. Security Architecture

### 6.1 Backup Code Generation

```
For each of 10 codes:
  1. code = Random.secure().nextCode()  // 8 alphanumeric chars, XXXX-XXXX
  2. salt = Random.secure().nextBytes(16)
  3. hash = Argon2id(password: code, salt: salt, params: same as MP)
  4. Store: { "hash": hex(hash), "salt": hex(salt) }
```

- Each code has its **own salt** — no batch cracking.
- Argon2id parameters match MP: 64MB memory, 2 iterations, 1 parallelism, 32-byte output.
- Plain codes returned ONCE to UI, never stored. User must save them.
- JSON array stored in `backup_code_hashes` column.

### 6.2 Atomic Code Consumption

```
BEGIN TRANSACTION
  1. Parse backup_code_hashes JSON → List<{hash, salt}>
  2. For each entry, compute Argon2id(code, salt) → compare hash
  3. If match at index i: splice List (remove i)
  4. Serialize updated List → json
  5. UPDATE master_password_config SET backup_code_hashes = ?
COMMIT
```

- If COMMIT fails, code hash is NOT removed — **safe to retry**.
- If code doesn't match any hash → ROLLBACK (no change).
- Code confirmed consumed only after COMMIT succeeds.

### 6.3 Rate Limiting

| Scenario | Limit | Implementation |
|----------|-------|---------------|
| Wrong MP attempts | 5 attempts, then 30s lockout | In-memory counter + timestamp in controller |
| Wrong backup code attempts | 3 attempts, then 60s lockout | In-memory counter + timestamp in recovery service |

Rate limits are **in-memory only** — survive screen navigation but not app restart. This is acceptable for an offline app (attacker has physical device access — local rate limiting is defense-in-depth, not primary protection).

### 6.4 Wrapping Key Security

| Property | Detail |
|----------|--------|
| DEK length | 32 bytes (256 bits) — AES-256-GCM key |
| DEK storage | Only on disk encrypted with KEK, only in memory in plaintext |
| KEK derivation | Argon2id(password, 16-byte random salt), 64MB memory, 2 iterations |
| DEK encryption | AES-256-GCM encrypt(DEK, key=KEK, nonce=12 random bytes) |
| Re-key (MP change) | Decrypt DEK with old KEK → re-encrypt with new KEK — O(1) |

### 6.5 What We DO NOT Store

| Never stored | Why |
|-------------|-----|
| Plain backup codes | Shown once, user must save externally |
| Master password in plaintext | Only KEK via Argon2id |
| DEK in plaintext on disk | Encrypted with KEK at rest |
| Session tokens | Offline-only app |

---

## 7. Error Handling

### Error Matrix

| Scenario | Error | User sees | System action |
|----------|-------|-----------|---------------|
| DB write fails during code consumption | `DatabaseException` | "Error al verificar código. Intentá de nuevo." | Code NOT consumed — retry safe |
| Code doesn't match any hash | None | "Código inválido o ya fue usado." | No DB change |
| Wrong MP on change | `invalidPassword` | "Contraseña actual inválida." | No change |
| Wrong MP on reveal (3+ attempts) | Rate limit | "Demasiados intentos. Esperá 30 segundos." | Lockout timer starts |
| `encryptedStorageKey` is null but entries require auth | Data integrity error | "Error de configuración. Reconfigurá tu master password en Ajustes." | Clear cached DEK, show settings |
| JSON parse failure on `backup_code_hashes` | `FormatException` | "Error de datos de recuperación. Regenerá tus códigos." | Show settings with regenerate option |
| Argon2id derivation failure | `CryptographyException` | "Error interno de seguridad. Cerra y reabrí la app." | Clear all cached state |
| User tries to delete MP while entries are protected | Validation | "Hay N entradas protegidas. Descifralas antes de eliminar la MP." | Block deletion, show count |

### Recovery from Errors

| Error | Recovery path |
|-------|--------------|
| DB write on consume | Retry — code wasn't consumed |
| Wrong code entry | User can try another code |
| All codes exhausted | User loses access (documented at setup) |
| Corrupted config | Delete and re-create MP (lose protected entries) |
| Rate-limited | Wait 30/60s |

---

## 8. Implementation Order

This order minimizes risk: schema first, then crypto, then store, then domain, then UI.

| Step | Files | Why first |
|------|-------|-----------|
| **1. Schema + migration** | `master_password_config_table.dart`, `app_database.dart` | Foundation — everything depends on new columns |
| **2. Wrapping key crypto** | `entry_auth_service.dart` (+encryptStorageKey, +decryptStorageKey, +generateBackupCodes) | Low-risk, isolated, testable |
| **3. MasterPasswordStore** | `master_password_store.dart` (+CRUD, +atomic consume) | Depends on schema, provides data to everything |
| **4. Domain service** | `master_password_recovery_service.dart` | Pure logic, depends on store + auth service, easily unit-testable |
| **5. Providers** | `entry_providers.dart`, `settings_providers.dart` | Wire domain to UI |
| **6. Refactor controller** | `credential_protection_controller.dart` | Uses store + auth service + providers |
| **7. Settings screen** | `settings_screen.dart`, `master_password_setup_dialog.dart`, `master_password_change_dialog.dart` | New UI, no regressions on existing flows |
| **8. Recovery dialog** | `master_password_recovery_dialog.dart` | New UI, independent |
| **9. Modify reveal flow** | `entry_detail_view.dart` | Touch existing code last — higher risk |
| **10. Tests** | See §9 | All layers |

---

## 9. Testing Strategy

### 9.1 Unit Tests (Domain)

| Test | What it verifies |
|------|-----------------|
| `should_verify_backup_code_when_hash_matches` | Correct code → `VerificationResult.success` |
| `should_reject_backup_code_when_hash_mismatches` | Wrong code → `VerificationResult(success: false)` |
| `should_not_consume_code_on_db_failure` | DB error → `ConsumptionResult(success: false)`, code hash unchanged |
| `should_consume_code_atomically` | Successful consume → hash removed from list |
| `should_change_mp_without_touching_entries` | MP change → only `master_password_config` updated |
| `should_reject_too_short_hint` | Hint < 3 chars → validation error |
| `should_generate_10_codes` | `generateBackupCodes()` → 10 unique codes |
| `should_validate_hint_max_length` | Hint > 200 chars → validation error |

### 9.2 Widget Tests (UI)

| Test | What it verifies |
|------|-----------------|
| `should_show_backup_codes_after_setup` | Setup dialog → codes displayed with copy/save |
| `should_show_hint_in_reveal_dialog` | Reveal prompt → hint displayed |
| `should_show_recovery_link_on_wrong_password` | Wrong MP → "Usar código de recuperación" visible |
| `should_open_recovery_dialog_from_link` | Tap recovery link → `RecoveryDialog` opens |
| `should_show_settings_with_mp_actions_when_configured` | Settings with config → change/regenerate buttons visible |
| `should_show_settings_with_setup_button_when_not_configured` | Settings without config → "Configurar" visible |
| `should_show_rate_limit_error` | 3 wrong codes → lockout message |

### 9.3 Integration Tests

| Test | What it verifies |
|------|-----------------|
| `should_migrate_v2_to_v3_with_existing_data` | Open v2 DB → v3 migration applies → hint/null, codes/null |
| `should_persist_and_verify_backup_code` | Generate codes → store → verify → consume |
| `should_not_decrypt_with_wrong_mp_after_change` | Setup MP → protect entry → change MP → reveal → KEK changed → can't decrypt |
| `should_decrypt_after_same_mp_reentry` | Setup MP → protect → session end → re-enter same MP → decrypt success |
| `should_consume_code_only_once` | Same code twice → first OK, second "ya usado" |
| `should_fail_when_all_codes_consumed` | Consume 10/10 → no codes left → error |

### 9.4 Security Tests

| Test | What it verifies |
|------|-----------------|
| `should_not_store_plaintext_codes_in_db` | After setup → DB has hashes, no plain codes |
| `should_generate_unique_salt_per_code` | All 10 codes have different salts |
| `should_not_leak_key_in_logs_or_stacktraces` | `Uint8List` keys never converted to string in logging paths |

---

## Appendix: New EntryAuthService Methods

```dart
/// Encrypts a 32-byte storage key (DEK) with the master key (KEK).
/// Returns: hex(ciphertext + nonce + tag) — single concatenated hex string.
Future<String> encryptStorageKey({
  required Uint8List storageKey,
  required Uint8List masterKey,
}) async {
  final nonce = _randomBytes(12);
  final secretBox = await _cipher.encrypt(
    storageKey,
    secretKey: SecretKey(masterKey),
    nonce: nonce,
  );
  // Encode as: ciphertext || nonce || mac
  final combined = Uint8List.fromList([
    ...secretBox.cipherText,
    ...secretBox.nonce,
    ...secretBox.mac.bytes,
  ]);
  return _toHex(combined);
}
```

```dart
/// Decrypts a storage key (DEK) from the combined hex string.
Future<Uint8List> decryptStorageKey({
  required String encryptedHex,
  required Uint8List masterKey,
}) async {
  final combined = _fromHex(encryptedHex);
  // Parse: ciphertext(32) || nonce(12) || mac(16) = 60 bytes total
  final ciphertext = combined.sublist(0, 32);
  final nonce = combined.sublist(32, 44);
  final mac = combined.sublist(44, 60);

  final secretBox = SecretBox(
    ciphertext,
    nonce: nonce,
    mac: Mac(mac),
  );

  final clearBytes = await _cipher.decrypt(
    secretBox,
    secretKey: SecretKey(masterKey),
  );
  return Uint8List.fromList(clearBytes);
}
```

---

## Appendix: Dependencies

| Dependency | Version | Used for |
|-----------|---------|----------|
| `cryptography` | ~3.0 | AES-256-GCM, Argon2id, random bytes |
| `flutter_riverpod` | ^2.x | State management |
| `drift` | ^2.x | ORM, migrations |
| `go_router` | ^14.x | Navigation (to settings) |
| `freezed` | ^2.x | Data classes (optional for results) |

No external dependencies added. All crypto is already in the project.
