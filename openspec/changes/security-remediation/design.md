# Design: Security Remediation — PR #2 (SQLite Encryption) & PR #3 (Encrypted Export)

## PR #2: SQLite Encryption (Finding A)

### Technical Approach

Replace `NativeDatabase(file)` with `NativeDatabase.createInBackground(file, setup: ...)` using SQLite3MultipleCiphers (SQLCipher-compatible). The encryption key is the existing DEK, derived from the user's master password via the established KEK/DEK pattern. On first launch after upgrade, migrate the unencrypted DB to an encrypted copy using `sqlcipher_export`.

### Architecture Decisions

#### Decision: SQLite3MultipleCiphers via build hooks (NOT sqlcipher_flutter_libs)

**Choice**: Use `sqlite3` package v3.x with `sqlite3_multiple_ciphers` build hook
**Alternatives**: `sqlcipher_flutter_libs` + manual override, `encrypted_drift` (sqflite-based)
**Rationale**: Since Dart SDK 3.11 and `sqlite3` v3.x, build hooks automatically bundle SQLite3MultipleCiphers. No manual `open.overrideFor()` needed. `encrypted_drift` requires sqflite which conflicts with the project's FFI-based Drift setup. The build-hook approach is zero-config, works cross-platform (Android, iOS, Linux, Windows), and is the officially recommended path.

#### Decision: Encrypt full database with DEK (column-level encryption NOT needed)

**Choice**: SQLCipher transparent page-level encryption via `PRAGMA key`
**Alternatives**: Application-level column encryption (encrypt title/content/tags/metadata individually)
**Rationale**: SQLCipher encrypts at the SQLite page level — all data (tables, FTS5 index, metadata) is encrypted at rest with zero application code changes to queries. Column-level encryption would require encrypting/decrypting every read/write, breaking FTS5 search, and doubling the code surface. The DEK (32-byte random key) is already managed by the existing KEK/DEK infrastructure.

#### Decision: Migration via `sqlcipher_export` ATTACH pattern

**Choice**: Open unencrypted DB, ATTACH encrypted DB with KEY, `SELECT sqlcipher_export`, transfer `user_version`
**Alternatives**: Read all rows in Dart, insert into new encrypted DB; PRAGMA rekey
**Rationale**: `sqlcipher_export` is atomic, handles all table types (including FTS5 virtual tables), and preserves binary data. Row-by-row Dart migration would be slow and fragile. `PRAGMA rekey` doesn't work on existing unencrypted databases. The migration pattern is documented by the Drift maintainer.

### Data Flow — DB Migration

```
App Start
  │
  ▼
Check: encrypted DB file exists?
  ├─ YES → Open with PRAGMA key → normal operation
  └─ NO  → Check: unencrypted DB exists?
       ├─ YES → MIGRATE:
       │   1. Prompt MP → unwrap DEK
       │   2. Open unencrypted DB (NativeDatabase)
       │   3. sqlite3.open(unencrypted) → ATTACH encrypted DB KEY dek_hex
       │   4. SELECT sqlcipher_export('encrypted')
       │   5. DETACH, read user_version, apply to encrypted DB
       │   6. Verify row count matches
       │   7. Delete unencrypted file
       │   8. Open encrypted DB with PRAGMA key
       └─ NO  → Fresh install: create encrypted DB directly
```

### Data Flow — Normal Operation

```
App Start
  │
  ▼
_openConnection()
  │
  ▼
NativeDatabase.createInBackground(
  encryptedFile,
  setup: (rawDb) {
    rawDb.execute("PRAGMA key = '${dek_hex}'");
  },
)
  │
  ▼
Drift opens DB → all queries transparent
```

### File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/infrastructure/database/app_database.dart` | Modify | Replace `_openConnection()` to use `NativeDatabase.createInBackground` with `setup` PRAGMA key. Add `static String? _dekHex` field and `setEncryptionKey()` method. |
| `lib/infrastructure/database/db_encryption_service.dart` | Create | Encapsulates migration logic: detect unencrypted DB, run `sqlcipher_export`, verify, cleanup. |
| `lib/ui/providers/entry_providers.dart` | Modify | After DEK unwrap in `CredentialProtectionController`, call `AppDatabase.setEncryptionKey(dekHex)` before DB access. |
| `pubspec.yaml` | Modify | Add `sqlite3: ^3.0.0` (already present as `^2.7.4` — upgrade). Add `sqlite3_multiple_ciphers` hook config. |

### API Design

```dart
// app_database.dart additions
class AppDatabase extends _$AppDatabase {
  static String? _dekHex;

  /// Must be called BEFORE any database access.
  /// Sets the encryption key for SQLCipher PRAGMA key.
  static void setEncryptionKey(Uint8List dek) {
    _dekHex = bytesToHex(dek);
  }

  AppDatabase() : super(_openConnection());
  // ...
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File('${dbFolder.path}/${AppConstants.databaseName}');
    final encryptedFile = File('${dbFolder.path}/${AppConstants.databaseName}.enc');

    // Run migration if needed (unencrypted → encrypted)
    await DbEncryptionService.migrateIfNeeded(
      unencryptedFile: file,
      encryptedFile: encryptedFile,
      dekHex: AppDatabase._dekHex!,
    );

    return NativeDatabase.createInBackground(
      encryptedFile,
      setup: (rawDb) {
        rawDb.execute("PRAGMA key = '${AppDatabase._dekHex}'");
      },
    );
  });
}
```

```dart
// db_encryption_service.dart — key method
static Future<void> migrateIfNeeded({
  required File unencryptedFile,
  required File encryptedFile,
  required String dekHex,
}) async {
  if (await encryptedFile.exists()) return; // already migrated
  if (!await unencryptedFile.exists()) return; // fresh install

  final tmpFile = File('${encryptedFile.path}.tmp');

  // Open unencrypted source
  final srcDb = sqlite3.open(unencryptedFile.path);
  final userVersion = srcDb.select('PRAGMA user_version;').first.columnAt(0) as int;

  // ATTACH encrypted DB and export
  final escapedKey = dekHex.replaceAll("'", "''");
  srcDb.execute("ATTACH DATABASE '${tmpFile.path}' AS encrypted KEY '$escapedKey'");
  srcDb.select("SELECT sqlcipher_export('encrypted')");
  srcDb.execute('DETACH DATABASE encrypted');
  srcDb.dispose();

  // Apply user_version to encrypted DB
  final encDb = sqlite3.open(tmpFile.path);
  encDb.execute("PRAGMA key = '$escapedKey'");
  encDb.execute('PRAGMA user_version = $userVersion');
  encDb.dispose();

  // Verify row count before delete
  // ... (read count from both, assert match)

  // Atomic swap: tmp → encrypted, delete unencrypted
  await tmpFile.rename(encryptedFile.path);
  await unencryptedFile.delete();
}
```

### Error Handling

| Failure | Fallback |
|---------|----------|
| DEK not set before DB open | `StateError('Encryption key not set')` — hard fail, prevents unencrypted access |
| `sqlcipher_export` fails mid-migration | Keep both files; next launch retries (idempotent check) |
| Row count mismatch after migration | Abort delete of old file, log error, keep both |
| Wrong DEK on open | SQLite throws "file is not a database" — surface as "Incorrect master password" |
| FTS5 not encrypted | SQLCipher encrypts virtual tables by default — verify with `PRAGMA cipher_page_size` |

### Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `DbEncryptionService.migrateIfNeeded` | In-memory DBs: create unencrypted, migrate, verify data intact |
| Unit | `setEncryptionKey` + `_openConnection` | Mock file system, verify PRAGMA key is executed |
| Integration | Full migration flow | Real files: create unencrypted DB with data → migrate → read back |
| Integration | Fresh install creates encrypted DB | Delete all DB files, open AppDatabase, verify encrypted |
| Widget | Settings screen export after encryption | Verify export reads decrypted data from encrypted DB |

---

## PR #3: Encrypted Export (Finding D)

### Technical Approach

Add passphrase-protected export using the existing `EntryAuthService` (AES-256-GCM + Argon2id). Export wraps the entire JSON payload; import detects encryption via `version` field. Backward-compatible with v1 plaintext exports.

### Architecture Decisions

#### Decision: Reuse EntryAuthService for encryption (NOT a new service)

**Choice**: Extend `EntryAuthService` with export-specific methods
**Alternatives**: Create `EncryptedExportService` separate from `EntryAuthService`
**Rationale**: `EntryAuthService` already has AES-256-GCM, Argon2id, salt generation. Adding export methods keeps crypto primitives centralized. The DEK/KEK pattern is reused — export passphrase → Argon2id → export-KEK → AES-256-GCM wraps payload.

#### Decision: Encrypt entire JSON payload as single ciphertext blob

**Choice**: Serialize entries to JSON string → encrypt whole string → output `{version:2, salt_hex, nonce_hex, tag_hex, ciphertext_hex}`
**Alternatives**: Encrypt individual fields per entry
**Rationale**: Single-blob encryption is simpler, smaller (no per-entry overhead), and preserves the JSON structure for inspection of the envelope. Per-entry encryption adds complexity with no security benefit (the file is either fully accessible or not).

#### Decision: User-provided passphrase (NOT master password)

**Choice**: Separate passphrase for export, entered via dialog
**Alternatives**: Use master password for export encryption; auto-encrypt with DEK
**Rationale**: Export passphrase is independent of the vault's DEK. This allows sharing exports with someone who has the passphrase but not the MP. Auto-encrypt with DEK would make exports useless without the vault's MP — defeating the purpose of portability.

### Data Flow — Encrypted Export

```
User taps "Export" → Disclaimer dialog → Passphrase dialog (enter + confirm)
  │
  ▼
Argon2id(passphrase, random_16_byte_salt) → exportKEK
  │
  ▼
entries.map(e => e.toJson()) → JSON string
  │
  ▼
AES-256-GCM(json_bytes, exportKEK, random_12_byte_nonce) → ciphertext + tag
  │
  ▼
Write JSON: {version:2, salt_hex, nonce_hex, tag_hex, ciphertext_hex}
```

### Data Flow — Import Detection

```
User picks file → Read JSON
  │
  ▼
Check wrapper['version']
  ├─ null or 1 → Plaintext import (existing flow)
  └─ 2 → Encrypted:
       ├─ Prompt passphrase dialog
       ├─ Argon2id(passphrase, salt_hex) → exportKEK
       ├─ AES-256-GCM.decrypt(ciphertext_hex, exportKEK, nonce_hex, tag_hex)
       ├─ Parse decrypted JSON as entries
       └─ Import entries (existing dedup logic)
```

### File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/infrastructure/export/encrypted_export_service.dart` | Create | `encryptExport(List<Entry>, passphrase)` → encrypted JSON string. `decryptExport(String, passphrase)` → `List<Entry>`. |
| `lib/infrastructure/export/export_service.dart` | Modify | Add `exportToJsonEncrypted(entries, passphrase)` that wraps the plaintext export with encryption. Change `saveToFile` extension to `.json` (same). |
| `lib/infrastructure/export/import_service.dart` | Modify | Detect `version:2` in wrapper, prompt for passphrase, decrypt before importing. |
| `lib/ui/screens/settings_screen.dart` | Modify | Add passphrase dialog before export. Add passphrase prompt on import when file is v2. |
| `lib/infrastructure/security/entry_auth_service.dart` | Modify | Add `exportEncrypt(plaintext, passphrase)` and `exportDecrypt(ciphertext, passphrase)` methods (Argon2id + AES-256-GCM). |

### API Design

```dart
// encrypted_export_service.dart
class EncryptedExportService {
  final EntryAuthService _authService;

  EncryptedExportService({required EntryAuthService authService})
      : _authService = authService;

  /// Encrypts a JSON export payload with a user-provided passphrase.
  /// Returns the encrypted JSON envelope string.
  Future<String> encryptExport({
    required String plaintextJson,
    required String passphrase,
  }) async {
    final salt = _authService.generateSalt(); // 16 bytes
    final key = await _authService.deriveMasterKey(
      password: passphrase,
      salt: salt,
    );
    final payload = await _authService.encryptSecret(
      plaintext: plaintextJson,
      masterKey: key,
    );
    return jsonEncode({
      'version': 2,
      'salt_hex': _authService.bytesToHex(salt),
      'nonce_hex': payload.nonceHex,
      'tag_hex': payload.tagHex,
      'ciphertext_hex': payload.ciphertextHex,
    });
  }

  /// Decrypts an encrypted export envelope.
  /// Throws if passphrase is wrong (AES-GCM tag verification fails).
  Future<String> decryptExport({
    required String encryptedJson,
    required String passphrase,
  }) async {
    final wrapper = jsonDecode(encryptedJson) as Map<String, dynamic>;
    final salt = _authService.hexToBytes(wrapper['salt_hex'] as String);
    final key = await _authService.deriveMasterKey(
      password: passphrase,
      salt: salt,
    );
    return _authService.decryptSecret(
      payload: EncryptionPayload(
        ciphertextHex: wrapper['ciphertext_hex'],
        nonceHex: wrapper['nonce_hex'],
        tagHex: wrapper['tag_hex'],
      ),
      masterKey: key,
    );
  }
}
```

### Passphrase UX

| Step | Dialog |
|------|--------|
| Export | Two fields: passphrase + confirm. Min 8 chars. Mismatch error inline. |
| Import (v2 file) | Single field: passphrase. Wrong passphrase → "Contraseña incorrecta" (AES-GCM tag fail). |
| Import (v1 file) | No passphrase prompt (backward compatible). |

### Error Handling

| Failure | Fallback |
|---------|----------|
| Passphrase too short (<8 chars) | Reject with inline error, don't proceed |
| Mismatched passphrases on export | Reject with "Las contraseñas no coinciden" |
| Wrong passphrase on import | AES-GCM tag verification throws → "Contraseña incorrecta" |
| Corrupted ciphertext | Same as wrong passphrase (tag verification) |
| Argon2id memory pressure | Desktop: 64MB is fine. Mobile: may need to reduce memory param |

### Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `encryptExport` round-trip | Encrypt → decrypt → assert JSON matches original |
| Unit | Wrong passphrase rejects | Encrypt with "pass1", decrypt with "pass2" → throws |
| Unit | Same passphrase, different salts | Two encryptions → different salt_hex, different ciphertext |
| Unit | v1 import still works | Parse plaintext JSON → entries imported |
| Unit | v2 import with correct passphrase | Parse encrypted → decrypt → entries imported |
| Unit | v2 import with wrong passphrase | Parse encrypted → decrypt → throws |
| Integration | Full export/import cycle | Create entries → export encrypted → import → verify same entries |
| Widget | Settings screen passphrase dialog | Tap export → dialog appears → enter passphrase → file saved |

---

## Shared Concerns

### Binary Size Impact

SQLite3MultipleCiphers adds ~1.5MB to the binary (vs plain SQLite). Acceptable for a security-focused vault app. No separate `.so`/`.dll` bundling needed — build hooks handle it.

### Key Lifecycle

Export passphrase is ephemeral — never stored, zeroed from memory after use (follows DEK zeroing pattern from PR #4). The export-KEK exists only during the encrypt/decrypt operation.

### Sequencing

PR #2 (DB encryption) should merge before PR #3 (encrypted export). PR #3 reads from the DB — if the DB is encrypted, Drift handles decryption transparently, so PR #3 doesn't strictly depend on PR #2. But testing the full flow (encrypted DB + encrypted export) requires both.

### Open Questions

- [ ] Should encrypted exports use a different Argon2id parameter set than the MP derivation? (Recommendation: same params — 65536 memory, 3 iterations, parallelism 1)
- [ ] Should the passphrase dialog show strength meter? (Recommendation: no — min 8 chars is sufficient for export, not a vault password)
- [ ] Migration race condition: what if user kills app mid-migration? (Answer: idempotent retry on next launch — tmp file exists but encrypted doesn't → retry)
