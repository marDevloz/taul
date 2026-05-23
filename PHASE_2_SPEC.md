# 📋 ESPECIFICACIÓN SDD – Fase 2: Per-Entry Protection

**Taúl — Almacenamiento Personal Minimalista, Rápido y Seguro**

**Versión:** 2.0-Phase2-Specification  
**Fecha:** 2025  
**Estado:** ✅ APROBADA (basada en PHASE_2_PROPOSAL_v2_SIMPLIFIED.md)  
**Responsable:** Arquitectura  

---

## 1. Executive Summary

**Delta Spec:** Sistema de protección de entradas individuales mediante cifrado AES-256-GCM + contraseña maestra Argon2id derivada, permitiendo que usuarios protejan selectivamente credenciales críticas sin fricción global, mientras mantienen búsqueda y acceso normal a entradas no protegidas.

**Scope:** Per-entry auth layer con cifrado simétrico, sin vault global, sin timeout, sin biometría (Phase 2.1).

---

## 2. Requirements (Delta from Phase 1)

### 2.1 Functional Requirements

| ID | Requirement | Acceptance Criteria | Priority |
|----|----|----|----|
| **FR-2.1** | Protección selectiva por entrada | Entry puede marcarse con `requiresAuth=true` | P0 |
| **FR-2.2** | Setup de contraseña maestra | Primera protección dispara setup dialog (una sola vez) | P0 |
| **FR-2.3** | Cifrado de secret | secret → AES-256-GCM con nonce + tag (cuando requiresAuth=true) | P0 |
| **FR-2.4** | Visualización de secret protegido | [Reveal Secret] button → password input → decrypt → show 30s → auto-hide | P0 |
| **FR-2.5** | Búsqueda FTS5 con protegidas | FTS5 busca en encrypted secrets; resultados muestran indicador 🔒 | P1 |
| **FR-2.6** | Protección multi-type | Todos los entry types (note, password, secret, url, etc.) pueden ser protegidos | P1 |
| **FR-2.7** | Performance búsqueda | Búsqueda < 200 ms (sin degradación Phase 1) | P0 |
| **FR-2.8** | Múltiples entradas protegidas | N entradas pueden estar protegidas con la misma master password | P1 |
| **FR-2.9** | Toggle on/off protección | User puede crear protegida, o cambiar existente a protegida en edit | P1 |
| **FR-2.10** | Edición de entrada protegida | Re-encriptación automática si secret cambia en entry protegida | P1 |

### 2.2 Non-Functional Requirements

| ID | Requirement | Specification | Priority |
|----|----|----|---|
| **NFR-2.1** | Cifrado | AES-256-GCM (mode strict) | P0 |
| **NFR-2.2** | KDF | Argon2id(t=2, m=65536, p=1) exacto | P0 |
| **NFR-2.3** | Nonce | 12 bytes random (Random.secure), new per encrypt | P0 |
| **NFR-2.4** | GCM Tag | 16 bytes, obligatorio, verify en decrypt | P0 |
| **NFR-2.5** | Master password storage | Hash Argon2id en master_password_config, NO plaintext | P0 |
| **NFR-2.6** | Derived key memory | Uint8List volatile (Riverpod state), cleared on exit | P0 |
| **NFR-2.7** | Plaintext security | NO master password en logs, NO secret en logs | P0 |
| **NFR-2.8** | Decrypt performance | < 200 ms (con Argon2id derivation) | P1 |
| **NFR-2.9** | Nonce uniqueness | Garantizado Random.secure(); verified en 100+ encrypts test | P0 |
| **NFR-2.10** | Migration safety | v1→v2 preserva todos datos existentes, nullable new columns | P0 |

### 2.3 Security Requirements

| ID | Requirement | Specification | Threat Mitigated |
|----|----|----|---|
| **SEC-2.1** | AEAD cipher | AES-256-GCM only (no streaming, no CBC) | Tampering, ciphertext modification |
| **SEC-2.2** | Key derivation resistance | Argon2id(t=2, m=65536, p=1) vs brute force | Rainbow tables, fast password cracking |
| **SEC-2.3** | Nonce uniqueness | Random.secure() every encrypt, NO reuse | Plaintext leakage in GCM mode |
| **SEC-2.4** | GCM tag verification | Mandatory verify before decryption | Detect tampering, replay attacks |
| **SEC-2.5** | Salt randomness | 16 bytes Random.secure() per master password | Dictionary attacks on multiple users |
| **SEC-2.6** | Key erasure | Uint8List cleared on app exit | Memory forensics post-exit |
| **SEC-2.7** | Logging hygiene | NO plaintext secret, NO master key in ANY log | Information disclosure |
| **SEC-2.8** | No password persistence | Master password NEVER stored on disk | Reverse engineering, device theft |
| **SEC-2.9** | Nonce encoding | Hex-encoded storage (12 bytes → 24 chars) | Data integrity in DB |
| **SEC-2.10** | Tag encoding | Hex-encoded storage (16 bytes → 32 chars) | Data integrity in DB |

---

## 3. Data Models & Schema

### 3.1 Entry Entity (MODIFIED from Phase 1)

**Phase 1 Schema:**
```dart
Entry {
  int id (PK)
  String topicKey (FK)
  String type
  String title
  String secret      // ← PLAINTEXT
  String content
  DateTime createdAt
  DateTime updatedAt
}
```

**Phase 2 Schema (DELTA):**
```dart
Entry {
  int id (PK)
  String topicKey (FK)
  String type
  String title
  String? secret     // ← NOW NULLABLE (encrypted entries have NULL here)
  String content
  
  // ========== NUEVA FASE 2 ==========
  bool requiresAuth  // Default: false
  String? encryptedSecret  // NULL if requiresAuth=false
  String? cipherNonce      // NULL if requiresAuth=false  (12 bytes → hex 24 chars)
  String? cipherTag        // NULL if requiresAuth=false  (16 bytes → hex 32 chars)
  
  DateTime createdAt
  DateTime updatedAt
}
```

**Invariants:**
- If `requiresAuth=true` → `secret` MUST be NULL, `encryptedSecret` NOT NULL
- If `requiresAuth=false` → `secret` can be any value, `encryptedSecret` MUST be NULL
- `cipherNonce` and `cipherTag` MUST both exist or both NULL (atomic pair)
- All 4 new columns default to NULL/false on creation

### 3.2 MasterPasswordConfig Entity (NEW)

```dart
MasterPasswordConfig {
  int id        // PK, always = 1 (singleton pattern)
  String passwordHashArgon2  // Argon2id(password, salt) → 32 bytes → hex (64 chars)
  String saltHex             // 16 bytes random → hex (32 chars)
  DateTime createdAt
  DateTime updatedAt
}
```

**Invariants:**
- 0 or 1 row in table (checked by app layer)
- `saltHex` is ONLY used for KDF; never for any other purpose
- Hash is NEVER used for encryption (only verification)

### 3.3 EncryptionResult Data Class (NEW)

```dart
class EncryptionResult {
  /// Ciphertext (without tag), hex-encoded
  /// Generated by AES-256-GCM encrypt(), tag stripped
  final String encryptedSecret;  // 32-N bytes → hex (64-2N chars)
  
  /// IV for GCM mode, hex-encoded
  /// Must be 12 bytes random per encryption
  final String nonce;  // 12 bytes → hex (24 chars)
  
  /// GCM authentication tag, hex-encoded
  /// Must be 16 bytes, generated by AES-256-GCM
  final String tag;  // 16 bytes → hex (32 chars)
}
```

### 3.4 Exceptions (NEW)

```dart
/// Base exception for auth/crypto errors
abstract class EntryAuthException implements Exception {
  final String message;
  EntryAuthException(this.message);
  
  @override
  String toString() => 'EntryAuthException: $message';
}

/// Thrown when GCM tag verification fails, password wrong, or tampering detected
class CryptoException extends EntryAuthException {
  CryptoException(String message) : super(message);
}

/// Thrown when master password not set, or auth check failed
class AuthException extends EntryAuthException {
  AuthException(String message) : super(message);
}

/// Thrown when database migration or schema mismatch occurs
class DatabaseException extends EntryAuthException {
  DatabaseException(String message) : super(message);
}
```

---

## 4. EntryAuthService Contract

**Purpose:** Single-responsibility service for encryption/decryption operations.  
**Lifecycle:** Singleton (via Riverpod provider)  
**Thread Safety:** All methods async (runs on Dart isolate or background thread if needed)

### 4.1 Method: deriveMasterKey

**Signature:**
```dart
Future<Uint8List> deriveMasterKey(
  String password,
  String saltHex,
)
```

**Purpose:** Derive 256-bit key from password using Argon2id KDF.

**Inputs:**
- `password` (String): Master password, any UTF-8 string (1-1000 chars recommended)
  - Edge case: Empty string → MUST throw AuthException("Password cannot be empty")
  - Edge case: Unicode (emojis, non-Latin) → MUST encode as UTF-8 before KDF
  - Edge case: Very long (>10KB) → MUST reject AuthException("Password too long")
  
- `saltHex` (String): Hex-encoded 16-byte salt (must be exactly 32 hex chars)
  - Edge case: Invalid hex → MUST throw CryptoException("Invalid salt hex")
  - Edge case: Wrong length → MUST throw CryptoException("Salt must be 16 bytes")

**Outputs:**
- Returns: `Uint8List` (exactly 32 bytes)
- MUST be deterministic: same password + salt → same key every time
- Thrown on error: `AuthException`, `CryptoException`

**Crypto Spec (EXACT):**
- Algorithm: Argon2id (NOT Argon2i, NOT Argon2d)
- Time cost (t): 2 (iterations)
- Memory cost (m): 65536 (64 MB)
- Parallelism (p): 1 (single thread)
- Hash length: 32 bytes (256 bits for AES-256)
- Salt: input `saltHex` decoded to bytes

**Performance:**
- Typical: 150-250 ms on modern phone
- MUST NOT exceed 500 ms (user experience acceptable)
- Must be async to avoid UI freeze

**Edge Cases:**
- Empty password → AuthException
- Unicode password (e.g., "contraseña🔐") → must work (UTF-8 encoding)
- Very long password (5000 chars) → should work but may reject
- Invalid hex salt → CryptoException
- Salt length mismatch → CryptoException

### 4.2 Method: encrypt

**Signature:**
```dart
EncryptionResult encrypt(
  String plaintext,
  Uint8List derivedKey,
)
```

**Purpose:** Encrypt plaintext with AES-256-GCM; return ciphertext + nonce + tag.

**Inputs:**
- `plaintext` (String): Secret to encrypt (any UTF-8, 1 byte - 1 MB)
  - Edge case: Empty string → MUST accept (empty ciphertext is valid)
  - Edge case: Very large (10 MB+) → SHOULD reject (performance)
  - Edge case: Unicode/binary → MUST handle as UTF-8
  
- `derivedKey` (Uint8List): MUST be exactly 32 bytes
  - Edge case: Wrong size → MUST throw CryptoException("Key must be 32 bytes")

**Outputs:**
- Returns: `EncryptionResult { encryptedSecret, nonce, tag }`
- `encryptedSecret`: Hex-encoded ciphertext (no tag included)
- `nonce`: Hex-encoded 12-byte nonce
- `tag`: Hex-encoded 16-byte GCM authentication tag
- Thrown on error: `CryptoException`

**Crypto Spec (EXACT):**
- Cipher: AES
- Key size: 256 bits (32 bytes input)
- Mode: GCM (Galois/Counter Mode)
- Nonce (IV) generation: 12 bytes via Random.secure()
- Tag size: 16 bytes (128 bits, standard for GCM)
- Authentication Data (AAD): None (AEAD, but no additional data)

**Behavior:**
- Each call MUST generate a NEW random nonce (no reuse)
- GCM tag is APPENDED to ciphertext by library, MUST be extracted
- Return: ciphertext + tag as separate hex strings in EncryptionResult
- MUST NOT modify derivedKey
- MUST NOT include tag in encryptedSecret field

**Nonce Uniqueness Guarantee:**
- MUST use `Random.secure()` ONLY (not default Random)
- For 12-byte nonce: 2^96 possible values (collision probability negligible)
- TEST: 100+ encrypts MUST produce 100+ unique nonces

**Performance:**
- Typical: 2-5 ms for 100-byte secret
- Typical: 20-50 ms for 1 MB secret
- MUST NOT block UI thread

**Edge Cases:**
- Empty plaintext → encrypt to empty ciphertext (valid)
- Unicode secret (e.g., "パスワード") → must work
- Special chars (null bytes within UTF-8) → must work
- Binary data as UTF-8 string → behaves like UTF-8 (may fail on invalid sequences)
- Key wrong size (24 bytes) → CryptoException

### 4.3 Method: decrypt

**Signature:**
```dart
Future<String> decrypt(
  String encryptedSecretHex,
  String nonceHex,
  String tagHex,
  Uint8List derivedKey,
)
```

**Purpose:** Decrypt ciphertext using AES-256-GCM; verify GCM tag; return plaintext.

**Inputs:**
- `encryptedSecretHex` (String): Hex-encoded ciphertext (no tag included)
  - Edge case: Empty string → valid (decrypts to empty plaintext)
  - Edge case: Invalid hex → MUST throw CryptoException("Invalid hex")
  
- `nonceHex` (String): Hex-encoded 12-byte nonce (exactly 24 hex chars)
  - Edge case: Wrong length → MUST throw CryptoException("Nonce must be 12 bytes")
  - Edge case: Invalid hex → MUST throw CryptoException("Invalid nonce hex")
  
- `tagHex` (String): Hex-encoded 16-byte GCM tag (exactly 32 hex chars)
  - Edge case: Wrong length → MUST throw CryptoException("Tag must be 16 bytes")
  - Edge case: Invalid hex → MUST throw CryptoException("Invalid tag hex")
  - Edge case: Tampered tag → MUST throw CryptoException("GCM tag verification failed")
  
- `derivedKey` (Uint8List): MUST be exactly 32 bytes
  - Edge case: Wrong size → MUST throw CryptoException("Key must be 32 bytes")

**Outputs:**
- Returns: `String` (plaintext, UTF-8 decoded)
- Thrown on error: `CryptoException` (tag failure, decryption failure, invalid input)

**Crypto Spec (EXACT):**
- Cipher: AES
- Key size: 256 bits (32 bytes)
- Mode: GCM
- Nonce: 12 bytes (from input)
- Tag verification: MANDATORY before decryption
  - GCM tag validation is ATOMIC; if tag fails, NO plaintext returned
  - Library MUST throw on tag mismatch

**Behavior:**
- Concatenate encryptedSecretHex + tagHex → full GCM output
- Pass to AES-256-GCM decrypt with nonce
- If tag verification fails → throw CryptoException (DO NOT return partial plaintext)
- If successful → return plaintext as UTF-8 string

**Error Handling:**
- Wrong password (derived key) → GCM tag verification fails → CryptoException
- Tampered ciphertext → GCM tag fails → CryptoException
- Tampered tag → GCM tag fails → CryptoException
- Invalid hex in inputs → CryptoException immediate (before decrypt)

**Performance:**
- Typical: 2-10 ms for 100-byte ciphertext
- MUST NOT exceed 200 ms for typical entry secrets (<10 KB)
- Must be async

**Edge Cases:**
- Empty encryptedSecretHex → decrypt to empty plaintext
- Wrong derivedKey → CryptoException (tag failure)
- Nonce from different encryption → CryptoException (tag failure)
- Ciphertext corrupted by 1 byte → CryptoException (tag failure)

### 4.4 Method: generateSalt

**Signature:**
```dart
String generateSalt()
```

**Purpose:** Generate random 16-byte salt for master password KDF.

**Inputs:** None

**Outputs:**
- Returns: `String` (hex-encoded 32 chars, representing 16 bytes)
- Example: `"a1b2c3d4e5f6789012345678abcdef01"`

**Behavior:**
- MUST use `Random.secure()` ONLY
- Generate 16 random bytes
- Encode to hex (lowercase or uppercase, consistent)

**Uniqueness:**
- Each call MUST produce different salt (overwhelmingly likely with Random.secure())

**Edge Cases:**
- None (always succeeds)

### 4.5 Method: hashPassword

**Signature:**
```dart
Future<String> hashPassword(
  String password,
  String saltHex,
)
```

**Purpose:** Hash password with Argon2id for verification storage.

**Inputs:**
- `password` (String): Master password to hash
- `saltHex` (String): Hex-encoded 16-byte salt (same as deriveMasterKey)

**Outputs:**
- Returns: `String` (hex-encoded hash, 64 chars for 32 bytes)
- Example: `"9c8f7e6d5c4b3a2918273645362718290"`

**Behavior:**
- Call `deriveMasterKey(password, saltHex)` internally
- Encode result to hex
- Return hex string

**Error Handling:**
- Same as deriveMasterKey (AuthException, CryptoException)

**Purpose of Hash vs Derived Key:**
- Derived key: for actual encryption/decryption
- Hash: for password verification (stored in DB, compared on unlock)
- They MUST be identical (hash = hex(derivedKey))

---

## 5. Riverpod Providers Contract

### 5.1 entryAuthServiceProvider

**Type:** `Provider<EntryAuthService>`

**Signature:**
```dart
final entryAuthServiceProvider = Provider(
  (ref) => EntryAuthService()
);
```

**Purpose:** Singleton instance of EntryAuthService.

**Lifecycle:**
- Created once per app start
- Never modified
- Destroyed on app exit

**Usage:**
```dart
final service = ref.watch(entryAuthServiceProvider);
final derivedKey = await service.deriveMasterKey(password, salt);
```

---

### 5.2 masterPasswordProvider

**Type:** `StateNotifierProvider<MasterPasswordNotifier, Uint8List?>`

**Signature:**
```dart
final masterPasswordProvider = StateNotifierProvider<
  MasterPasswordNotifier,
  Uint8List?
>(
  (ref) => MasterPasswordNotifier()
);
```

**State Shape:** `Uint8List? derivedKey`
- `null` → no master password derived/set in memory
- `Uint8List(32)` → derived key is in memory, ready for encrypt/decrypt

**Methods:**

#### 5.2.1 setMasterPassword

**Signature:**
```dart
Future<void> setMasterPassword(String password)
```

**Purpose:** Derive master key from password and store in state.

**Inputs:**
- `password` (String): Master password entered by user

**Behavior:**
1. Fetch `master_password_config` from DB (should exist)
2. Call `EntryAuthService.deriveMasterKey(password, config.saltHex)`
3. Store result in `state = derivedKey`
4. MUST be async (Argon2id takes 150-250 ms)

**Errors:**
- If `master_password_config` not found → throw AuthException("Master password not configured")
- If Argon2id fails → throw CryptoException
- If password empty → throw AuthException("Password cannot be empty")

**State Update:**
- ONLY updates if success
- On error, state remains unchanged (null or previous key)

#### 5.2.2 clearMasterPassword

**Signature:**
```dart
void clearMasterPassword()
```

**Purpose:** Clear derived key from memory.

**Behavior:**
- Set `state = null`
- Synchronous (immediate)

**Use Case:**
- User closes app (auto-clear on exit)
- User manually "lock" the app
- Timeout logic (if implemented future)

#### 5.2.3 isMasterPasswordSet

**Signature:**
```dart
bool isMasterPasswordSet()
```

**Purpose:** Check if derived key is currently in memory.

**Behavior:**
- Return `state != null`
- Synchronous

**Use Case:**
- UI: show "Locked" vs "Unlocked" indicator
- Logic: check if decrypt possible

### 5.3 unlockedEntriesProvider

**Type:** `StateNotifierProvider<UnlockedEntriesNotifier, Set<String>>`

**Signature:**
```dart
final unlockedEntriesProvider = StateNotifierProvider<
  UnlockedEntriesNotifier,
  Set<String>
>(
  (ref) => UnlockedEntriesNotifier()
);
```

**State Shape:** `Set<String>` (set of entry IDs that were revealed in this session)
- Empty set → no entries revealed
- `{"entry-1", "entry-2"}` → these 2 entries currently visible

**Methods:**

#### 5.3.1 markUnlocked

**Signature:**
```dart
Future<void> markUnlocked(String entryId)
```

**Purpose:** Mark entry as revealed, auto-clear after 30 seconds.

**Inputs:**
- `entryId` (String): ID of entry that was decrypted and shown

**Behavior:**
1. Add `entryId` to state: `state = {...state, entryId}`
2. Schedule auto-clear: `Future.delayed(Duration(seconds: 30), () { ... })`
3. After 30s, remove from set: `state = state..remove(entryId)` or rebuild set

**Idempotency:**
- Multiple calls with same entryId within 30s: MUST reset timer
  - Option A: Remove + re-add (reset timer)
  - Option B: Track last call time per ID (more complex, probably not needed)
  - Recommended: Option A for simplicity

**State Update:**
- Immediate add to state (synchronous return)
- Background timer for removal

#### 5.3.2 Auto-Clear Logic

**Behavior:**
- After 30 seconds from `markUnlocked()` call, entry MUST be removed from set
- If user calls markUnlocked again within 30s, timer resets (Option A above)
- If 30s passes without reset, entry is automatically removed

**Use Case:**
- UI: Show secret in plaintext for 30 seconds
- After 30s: Hide secret (show [Reveal] button again)
- Prevents accidental left-on screen after user walks away

**Timer Management:**
- Timers are NOT persisted; on app exit, all timers cancelled
- state is cleaned on exit anyway (app restart)

---

## 6. Database Schema & Migration

### 6.1 Phase 1 Schema (Baseline)

```sql
CREATE TABLE entries (
  id INTEGER PRIMARY KEY,
  topic_key TEXT NOT NULL,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  secret TEXT,
  content TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE topics (
  id INTEGER PRIMARY KEY,
  key TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- FTS5 virtual table (already exists in Phase 1)
CREATE VIRTUAL TABLE entries_search USING fts5(
  title, content, secret, topic_key
);
```

### 6.2 Phase 2 Schema (DELTA)

**New Columns in `entries` table:**

```sql
-- Run migrations in order:

ALTER TABLE entries ADD COLUMN requires_auth BOOLEAN DEFAULT 0;
ALTER TABLE entries ADD COLUMN encrypted_secret TEXT;
ALTER TABLE entries ADD COLUMN cipher_nonce TEXT;
ALTER TABLE entries ADD COLUMN cipher_tag TEXT;

-- New table for master password config
CREATE TABLE master_password_config (
  id INTEGER PRIMARY KEY,
  password_hash_argon2 TEXT NOT NULL,
  salt_hex TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Optional: create index for faster config lookup
CREATE UNIQUE INDEX idx_master_password_config_id ON master_password_config(id);
```

**Final Schema after Phase 2:**

```sql
CREATE TABLE entries (
  id INTEGER PRIMARY KEY,
  topic_key TEXT NOT NULL,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  secret TEXT,                -- ← NOW NULLABLE for encrypted entries
  content TEXT,
  
  -- PHASE 2 COLUMNS
  requires_auth BOOLEAN DEFAULT 0,
  encrypted_secret TEXT,       -- NULL if requires_auth=false
  cipher_nonce TEXT,           -- NULL if requires_auth=false; 12 bytes → hex (24 chars)
  cipher_tag TEXT,             -- NULL if requires_auth=false; 16 bytes → hex (32 chars)
  
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE TABLE master_password_config (
  id INTEGER PRIMARY KEY,
  password_hash_argon2 TEXT NOT NULL,  -- 32 bytes → hex (64 chars)
  salt_hex TEXT NOT NULL,              -- 16 bytes → hex (32 chars)
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- FTS5 table (unchanged from Phase 1)
-- Note: FTS5 searches encrypted_secret as well (if needed)
CREATE VIRTUAL TABLE entries_search USING fts5(
  title, content, secret, topic_key
);
```

### 6.3 Migration Implementation (Drift)

**File:** `lib/src/database/migrations/migration_v1_to_v2.dart`

```dart
// Pseudo-code (Drift migration syntax)

@migrate
Future<void> migrateV1ToV2(m.Migration migration) async {
  // Step 1: Add new columns to entries
  await migration.addColumn(
    'entries',
    m.Column(
      'requires_auth',
      m.ColumnType.boolean,
      defaultValue: 'false',
    ),
  );
  
  await migration.addColumn(
    'entries',
    m.Column(
      'encrypted_secret',
      m.ColumnType.text,
      defaultValue: 'null',
    ),
  );
  
  await migration.addColumn(
    'entries',
    m.Column(
      'cipher_nonce',
      m.ColumnType.text,
      defaultValue: 'null',
    ),
  );
  
  await migration.addColumn(
    'entries',
    m.Column(
      'cipher_tag',
      m.ColumnType.text,
      defaultValue: 'null',
    ),
  );
  
  // Step 2: Create master_password_config table
  await migration.createTable('master_password_config', (t) {
    t.integer('id', customConstraints: 'PRIMARY KEY');
    t.text('password_hash_argon2', customConstraints: 'NOT NULL');
    t.text('salt_hex', customConstraints: 'NOT NULL');
    t.integer('created_at', customConstraints: 'NOT NULL');
    t.integer('updated_at', customConstraints: 'NOT NULL');
  });
  
  // Step 3: NO data migration needed
  // All existing entries have requires_auth=false (default)
  // New encrypted entries are added afterwards
}
```

### 6.4 Data Preservation & Rollback

**Data Preservation:**
- All Phase 1 entries remain in DB with new columns NULL/default
- No data loss during migration
- `requires_auth=false` by default (backward compatible)
- FTS5 table unchanged (existing virtual table syntax compatible)

**Rollback Strategy (if needed):**
- Option A: Don't support (migrations are one-way in this project)
- Option B: Manual backup before migration + restore script
- Recommendation: Document backup procedure in deployment docs

**Validation After Migration:**
- Test on sample DB: ensure old entries still readable
- Test on sample DB: new columns exist and NULL
- Test on sample DB: master_password_config created (empty)

---

## 7. Workflows (Detailed Pseudo-Spec)

### 7.1 Workflow: Setup Master Password (First Time)

**Trigger:** User creates/edits entry and toggles `Protect this entry?` ON for first time.

**Actor:** User

**Preconditions:**
- `master_password_config` table empty (no master password set)
- User intends to protect an entry

**Flow:**

1. **User creates new entry** or **edits existing entry**
   - Fills in: title, type, secret, content
   - Toggles switch "Protect this entry?" → ON
   
2. **App checks:** Is master_password_config empty?
   - YES → Proceed to Step 3
   - NO → Skip to 7.2 (already setup)
   
3. **Show Master Password Setup Dialog**
   - Prompts: "Set up master password (first time only)"
   - Input 1: "Master Password" (password field, masked)
   - Input 2: "Confirm Password" (password field, masked)
   - Button: "Set & Protect Entry"
   - Button: "Cancel"
   
4. **Validation**
   - If Cancel: discard, return to edit form, toggle remains OFF
   - If both empty: show error "Password required"
   - If mismatch: show error "Passwords don't match, try again"
   - If valid: proceed to Step 5
   
5. **Derive & Store Master Password**
   ```
   salt = EntryAuthService.generateSalt()  // 16 random bytes → hex
   derivedKey = await EntryAuthService.deriveMasterKey(password, salt)
   hash = hex.encode(derivedKey)  // Store hash, not key
   
   INSERT INTO master_password_config VALUES (
     id=1,
     password_hash_argon2=hash,
     salt_hex=salt,
     created_at=now(),
     updated_at=now()
   )
   
   masterPasswordProvider.setMasterPassword(password)
   // → state = derivedKey (in memory)
   ```
   
6. **Encrypt Entry Secret**
   ```
   encResult = await EntryAuthService.encrypt(
     entry.secret,      // plaintext
     masterPasswordProvider.state  // derivedKey (32 bytes)
   )
   // → encResult = { encryptedSecret, nonce, tag }
   ```
   
7. **Save Entry to DB**
   ```
   entry.requiresAuth = true
   entry.secret = null  // Clear plaintext
   entry.encryptedSecret = encResult.encryptedSecret
   entry.cipherNonce = encResult.nonce
   entry.cipherTag = encResult.tag
   
   await entryRepository.createOrUpdate(entry)
   ```
   
8. **Success & Return**
   - Close dialog
   - Return to app
   - Entry saved with protection
   - Show success toast: "Entry protected ✓"

**Postconditions:**
- `master_password_config` now has 1 row
- New entry has `requiresAuth=true`, encrypted secret stored
- `derivedKey` in memory (user can create more protected entries without re-entering password)

**Alternate Flow: Cancel**
- User closes dialog or clicks Cancel
- No entry saved
- No master password created
- Return to edit form

---

### 7.2 Workflow: Create/Edit Protected Entry (Master Password Already Set)

**Trigger:** User creates/edits entry with `Protect this entry?` ON, master password already exists.

**Actor:** User

**Preconditions:**
- `master_password_config` table has 1 row (master password set)
- OR user just completed 7.1 (derived key in memory)

**Flow:**

1. **User creates/edits entry** with protection toggle ON

2. **Check:** Is derived key in memory?
   - YES (masterPasswordProvider.isMasterPasswordSet()) → Skip to Step 5
   - NO → Proceed to Step 3
   
3. **Show Password Input Sheet**
   - Prompt: "Enter master password to protect this entry"
   - Input: password field (masked)
   - Button: "Unlock"
   - Button: "Cancel"
   
4. **Verify Password**
   - If Cancel: return, toggle OFF, discard
   - Else: call `masterPasswordProvider.setMasterPassword(password)`
   - If throws CryptoException: show error "Wrong password, try again"
   - If throws AuthException: show error and fail
   - If success: derived key now in memory
   
5. **Encrypt & Save**
   - Same as 7.1 Step 6-7
   - Use `masterPasswordProvider.state` (already set)
   
6. **Success**
   - Entry saved with protection
   - Show toast: "Entry protected ✓"

**Postconditions:**
- Entry has `requiresAuth=true`, encrypted secret
- Derived key remains in memory (user can create more entries)

---

### 7.3 Workflow: View Protected Entry (Reveal Secret)

**Trigger:** User views entry with `requiresAuth=true`.

**Actor:** User

**Preconditions:**
- Entry exists with `requiresAuth=true`, encrypted_secret NOT NULL
- User wants to see the secret

**Flow:**

1. **User opens Entry Detail View**
   - Title, content displayed normally
   - Secret area shows "[🔒 Reveal Secret]" button (not plaintext)
   
2. **Check:** Is derived key in memory?
   - YES (masterPasswordProvider.isMasterPasswordSet()) → Skip to Step 5
   - NO → Proceed to Step 3
   
3. **Show Password Input Sheet**
   - Prompt: "Enter master password to reveal secret"
   - Input: password field (masked)
   - Button: "Unlock & Reveal"
   - Button: "Cancel"
   
4. **Verify Password**
   - If Cancel: close sheet, return to view (secret still hidden)
   - Else: call `masterPasswordProvider.setMasterPassword(password)`
   - If wrong/throws: show error "Wrong password, try again"
   - If success: continue to Step 5
   
5. **Decrypt Secret**
   ```
   plaintext = await EntryAuthService.decrypt(
     encryptedSecretHex = entry.encryptedSecret,
     nonceHex = entry.cipherNonce,
     tagHex = entry.cipherTag,
     derivedKey = masterPasswordProvider.state
   )
   // → plaintext = original secret
   ```
   
6. **Check GCM Tag & Handle Errors**
   - If decrypt throws CryptoException (tag fail, tampering):
     - Show error: "Secret could not be decrypted (possibly tampered or corrupted)"
     - Do NOT show partial plaintext
     - Do NOT proceed
   - Else: success, continue
   
7. **Display Secret (Plaintext)**
   ```
   unlockedEntriesProvider.markUnlocked(entryId)
   // → state adds entryId, schedules 30s removal
   
   Show secret in overlay/expanded section
   - Plaintext visible
   - Copy button
   - "Auto-hides in 30 seconds" message
   ```
   
8. **Auto-Hide After 30 Seconds**
   - After 30s: `unlockedEntriesProvider` auto-removes entryId
   - UI rebuilds: secret hidden again, show "[🔒 Reveal Secret]" button
   - User still can interact (copy-paste during 30s window)

9. **Return State**
   - User can close view, app navigates back
   - Derived key remains in memory
   - User can view another protected entry (no password prompt)

**Postconditions:**
- Secret visible for 30 seconds
- After 30s: hidden (but derived key still in memory)
- Entry marked as "unlocked in session"

**Error Handling:**
- Wrong password → error shown, no decryption
- Tampered ciphertext/tag → CryptoException, error shown
- Corrupt nonce/tag hex → CryptoException, error shown
- Missing encrypted_secret field → error shown (DB consistency check)

---

### 7.4 Workflow: Search Entries (FTS5 with Protected Entries)

**Trigger:** User searches via FTS5.

**Actor:** User

**Preconditions:**
- N entries, some with `requiresAuth=true`, some normal
- FTS5 table indexed on title, content, secret (Phase 1)

**Flow:**

1. **User enters search query** (e.g., "twitter")
   - Input: search box
   
2. **FTS5 Query** (unchanged from Phase 1)
   ```sql
   SELECT entries.* FROM entries
   JOIN entries_search ON entries.id = entries_search.rowid
   WHERE entries_search MATCH 'twitter'
   ```
   
3. **Results Processing**
   - For each entry:
     - If `requiresAuth=false` → show as normal
     - If `requiresAuth=true` → show with 🔒 indicator, masked secret
     
4. **Mask Protected Secrets in Results**
   ```
   For each result:
     if (result.requiresAuth):
       result.secret = "[🔒 Protected - Reveal to View]"
     else:
       result.secret = result.secret  // plaintext as normal
   ```
   
5. **Display Results**
   - List of matches
   - Protected entries show "[🔒 Protected]" instead of secret
   - User can click on any entry → flows to 7.3 (Reveal if protected)
   
6. **Performance**
   - FTS5 query time MUST be < 200 ms (unchanged from Phase 1)
   - No crypto operations during search (no decryption)
   - Encryption does NOT impact search performance

**Postconditions:**
- Search results displayed with proper masking
- User can click protected entry to reveal

---

### 7.5 Workflow: Edit Protected Entry

**Trigger:** User opens edit form for entry with `requiresAuth=true`.

**Actor:** User

**Preconditions:**
- Entry exists with `requiresAuth=true`
- User wants to edit (title, content, or secret)

**Flow:**

1. **Load Entry into Edit Form**
   - Title, content loaded normally
   - Secret: if protected, show "[🔒 Click to Reveal]" or input field with masked value
   
2. **Option A: Keep Protection, Update Secret**
   - User reveals secret (flow 7.3)
   - User edits secret in form
   - User saves
   - App re-encrypts new secret (new nonce + tag)
   - DB updated: `encryptedSecret`, `cipherNonce`, `cipherTag` replaced
   
3. **Option B: Remove Protection**
   - User toggles "Protect this entry?" OFF
   - Entry saved with:
     - `requiresAuth = false`
     - `secret = plaintext` (or show plaintext first)
     - `encryptedSecret = null`
     - `cipherNonce = null`
     - `cipherTag = null`
   
4. **Option C: Move Protection**
   - User toggles protection OFF, saves
   - Later, toggle ON again
   - Flows to 7.2 (if master password exists) or 7.1 (if not)

**Postconditions:**
- Entry updated with new state
- If secret changed and protected → new encryption (new nonce)

---

### 7.6 Workflow: Delete Protected Entry

**Trigger:** User deletes entry with `requiresAuth=true`.

**Actor:** User

**Preconditions:**
- Entry exists with protection
- User confirms deletion

**Flow:**

1. **User initiates delete** (trash icon, confirm dialog)
   - No special handling needed (same as unprotected)
   
2. **App deletes entry from DB**
   - SQL: `DELETE FROM entries WHERE id = ?`
   - FTS5 triggers auto-delete (virtual table sync)
   
3. **Success**
   - Entry removed (no recovery, by design)
   - Show toast: "Entry deleted"

**Postconditions:**
- Entry gone (including encrypted_secret, nonce, tag)

---

## 8. Security Specifications

### 8.1 Cryptographic Algorithms & Parameters

| Component | Algorithm | Parameters | Rationale |
|-----------|-----------|-----------|-----------|
| **Symmetric Encryption** | AES-256-GCM | 256-bit key, 12-byte nonce, 16-byte tag | Industry standard AEAD, immune to tampering |
| **Key Derivation** | Argon2id | t=2, m=65536, p=1, 32-byte output | Password hashing with memory-hard defense vs GPUs |
| **Random Generation** | Random.secure() | CSPRNG | Cryptographically secure randomness for nonce/salt |
| **Encoding** | Hex (Base16) | String (UTF-8) | Portable storage in SQLite TEXT columns |

### 8.2 Key Management

**Master Password:**
- NEVER stored on disk (only hash)
- NEVER logged
- Encoded as UTF-8 before KDF

**Derived Key (256-bit):**
- Derived from master password + salt via Argon2id
- Stored ONLY in memory (Riverpod state, Uint8List)
- Cleared on app exit (volatile memory)
- NOT persisted to disk

**Salt (16 bytes):**
- Generated once per master password setup
- Stored in `master_password_config.salt_hex` (hex-encoded)
- Used for KDF ONLY (not for encryption)

### 8.3 Nonce Management

**Requirement:** 12-byte nonce, fresh per encryption, NEVER reused.

**Implementation:**
```dart
final random = Random.secure();
final nonce = List<int>.generate(12, (_) => random.nextInt(256));
```

**Verification:**
- TEST: Encrypt same plaintext 100 times → produce 100 unique nonces
- Collision probability: 2^-96 (negligible)

**Encoding:**
- 12 bytes → hex (24 characters)
- Example: `"a1b2c3d4e5f6789012345678"`

### 8.4 GCM Tag Verification

**Requirement:** 16-byte GCM tag MUST be verified before decryption.

**Implementation:**
- AES-GCM library appends tag to ciphertext
- Decrypt operation verifies tag atomically
- If verification fails → throws exception (NO plaintext returned)

**Encoding:**
- 16 bytes → hex (32 characters)
- Example: `"a1b2c3d4e5f6789012345678abcdef01"`

**Threat Mitigation:**
- Detects tampering with ciphertext
- Detects replayed ciphertexts from different entries
- Detects wrong password (wrong key → tag fails)

### 8.5 Plaintext Protection

**No Plaintext in Logs:**
- Master password NEVER logged
- Secret plaintext NEVER logged during encrypt/decrypt
- Derived key NEVER logged

**Recommendation:**
- Use secure logging library (redact sensitive fields)
- Example: `logger.info("Encrypted entry ${entry.id}"); // NO secret`

### 8.6 Password Verification

**Flow:**
1. User enters password on unlock sheet
2. App calls `masterPasswordProvider.setMasterPassword(password)`
3. Provider calls `EntryAuthService.deriveMasterKey(password, salt)`
4. Derived key stored in state
5. Use derived key for decrypt (if GCM tag fails → wrong password detected)

**NO Explicit Hash Comparison:**
- We don't compare `hashPassword(input) == storedHash`
- Instead, we derive key and try to decrypt
- If decrypt fails (GCM tag invalid) → wrong password
- This is more user-friendly (same operation as actual decryption)

**Alternative (not implemented):**
- Could verify hash before attempting decrypt (optimization)
- But not necessary; GCM tag failure is sufficient

### 8.7 Threats Mitigated

| Threat | Mitigation | Mechanism |
|--------|-----------|-----------|
| **Plaintext credential theft** | AES-256-GCM encryption | Ciphertext stored, plaintext never on disk |
| **Rainbow table attack** | Argon2id + random salt | 2^128 possible salts, 200ms per hash attempt |
| **Brute force password** | Argon2id memory-hard | 65536 * 1 MB = ~65 MB per attempt, slow |
| **Tampering with ciphertext** | GCM tag verification | 16-byte tag, 2^-128 forgery probability |
| **Nonce reuse (GCM weakness)** | Random.secure() + unique per encrypt | 2^-96 collision probability (negligible) |
| **Key extraction from memory** | Volatile Uint8List, no persistence | Cleared on app exit, not in logs |
| **Wrong password detection** | GCM tag fails cleanly | No partial decryption leakage |
| **Replay attacks** | Nonce + tag binding | Same ciphertext fails in different context |
| **Device theft (locked state)** | Derived key not persisted | Attacker must know master password |
| **Device theft (unlocked state)** | User responsibility, not mitigated | Key in memory; user must close app |

### 8.8 Threats NOT Mitigated (Out of Scope)

| Threat | Reason | Mitigation (Future) |
|--------|--------|-----------|
| **Physical device access (unlocked)** | Key in memory; attacker has access | Timeouts, biometrics (Phase 2.1) |
| **Master password brute force (offline)** | Attacker has DB copy; can brute-force offline | Stronger password policy, recovery codes (Phase 2.1) |
| **Timing attacks on Argon2id** | Possible but negligible in practice | Constant-time library (cryptography package) |
| **Master password recovery** | Not implemented | Recovery codes or email verification (Phase 2.1) |
| **Biometric spoofing** | Biometrics not implemented (Phase 2.1) | Implement secure biometric flow later |

---

## 9. Error Handling Specification

### 9.1 Exception Hierarchy

```dart
abstract class EntryAuthException implements Exception {
  final String message;
  EntryAuthException(this.message);
}

class CryptoException extends EntryAuthException {
  // Thrown on: decrypt failure, GCM tag fail, tampering, crypto errors
}

class AuthException extends EntryAuthException {
  // Thrown on: master password not set, password empty, auth logic fails
}

class DatabaseException extends EntryAuthException {
  // Thrown on: migration failure, schema mismatch, DB errors
}
```

### 9.2 Error Scenarios & Handling

| Scenario | Exception | Message | User Facing | Recovery |
|----------|-----------|---------|------------|----------|
| **Empty password input** | AuthException | "Password cannot be empty" | "Please enter a password" | Retry |
| **Password > 10KB** | AuthException | "Password too long (max 10 KB)" | "Password is too long" | Use shorter password |
| **Passwords don't match (setup)** | AuthException | "Passwords don't match" | "Passwords don't match, try again" | Retry |
| **Wrong master password (unlock)** | CryptoException | "GCM tag verification failed" | "Wrong password, try again" | Retry or cancel |
| **Tampered ciphertext** | CryptoException | "GCM tag verification failed" | "Secret corrupted (tampering detected)" | No recovery (contact support) |
| **Invalid hex in DB** | CryptoException | "Invalid hex encoding" | "Database error (hex decode)" | No recovery (DB integrity issue) |
| **Nonce/tag wrong size** | CryptoException | "Nonce must be 12 bytes" | "Database error (schema)" | No recovery |
| **Derived key wrong size** | CryptoException | "Key must be 32 bytes" | "Encryption error (internal)" | No recovery |
| **Master password config not found** | AuthException | "Master password not configured" | "Protect this entry first?" or retry setup | Navigate to setup |
| **Argon2id timeout** | CryptoException | "KDF timeout" | "Password derivation took too long" | Retry, check device |
| **FTS5 query error** | DatabaseException | "Search query failed" | "Search failed, try again" | Retry |
| **Migration failure** | DatabaseException | "Migration v1→v2 failed: {reason}" | "Database upgrade failed" | Restore backup or contact support |

### 9.3 Error Logging (Security-Aware)

**DO LOG:**
- Entry IDs, operation type (encrypt, decrypt)
- Performance metrics (Argon2id time, decrypt time)
- User actions (started decrypt, etc.)

**DON'T LOG:**
- Master password (plaintext or hash)
- Derived key
- Plaintext secret
- User password input
- Full ciphertext (OK to log first 10 bytes for debugging)

**Example Safe Logging:**
```dart
logger.info("Encrypted entry ${entry.id}"); // OK
logger.info("Decrypt failed for entry ${entry.id}: CryptoException"); // OK
logger.warning("Argon2id took ${duration.inMilliseconds}ms"); // OK

// logger.debug("Master password is: $password"); // ❌ NEVER
// logger.debug("Derived key: $derivedKey"); // ❌ NEVER
// logger.debug("Secret plaintext: $secret"); // ❌ NEVER
```

---

## 10. Testing Requirements

### 10.1 Unit Tests (EntryAuthService)

| Test ID | Test Name | Scenario | Expected | Priority |
|---------|-----------|----------|----------|----------|
| **UT-1** | `test_generateSalt_returns_16_bytes` | Call generateSalt() | Returns 32-char hex (16 bytes) | P0 |
| **UT-2** | `test_generateSalt_uniqueness` | Call 100 times | 100 unique salts | P0 |
| **UT-3** | `test_deriveMasterKey_deterministic` | Same password + salt | Same key returned | P0 |
| **UT-4** | `test_deriveMasterKey_different_salt` | Same password, different salt | Different keys | P0 |
| **UT-5** | `test_deriveMasterKey_different_password` | Different password, same salt | Different keys | P0 |
| **UT-6** | `test_deriveMasterKey_empty_password` | deriveMasterKey("", salt) | Throws AuthException | P0 |
| **UT-7** | `test_deriveMasterKey_unicode_password` | Unicode password "パスワード" | Derives key (UTF-8 encoding) | P0 |
| **UT-8** | `test_deriveMasterKey_very_long_password` | 5000-char password | Works or throws AuthException | P0 |
| **UT-9** | `test_deriveMasterKey_invalid_salt_hex` | Invalid hex salt | Throws CryptoException | P0 |
| **UT-10** | `test_deriveMasterKey_wrong_salt_length` | 8-byte salt (not 16) | Throws CryptoException | P0 |
| **UT-11** | `test_deriveMasterKey_performance` | Time Argon2id | < 500 ms | P1 |
| **UT-12** | `test_encrypt_returns_valid_result` | encrypt(plaintext, key) | Returns EncryptionResult with 3 fields | P0 |
| **UT-13** | `test_encrypt_nonce_format` | Check nonce in result | Hex string, 24 chars (12 bytes) | P0 |
| **UT-14** | `test_encrypt_tag_format` | Check tag in result | Hex string, 32 chars (16 bytes) | P0 |
| **UT-15** | `test_encrypt_empty_plaintext` | encrypt("", key) | Valid result (empty ciphertext) | P0 |
| **UT-16** | `test_encrypt_unicode_plaintext` | encrypt("日本語秘密", key) | Encrypts UTF-8 (valid ciphertext) | P0 |
| **UT-17** | `test_encrypt_large_secret` | 1 MB plaintext | Encrypts successfully | P1 |
| **UT-18** | `test_encrypt_nonce_uniqueness` | Encrypt same plaintext 100x | 100 unique nonces | P0 |
| **UT-19** | `test_encrypt_performance` | Encrypt 100-byte secret | < 10 ms | P1 |
| **UT-20** | `test_encrypt_wrong_key_size` | Key != 32 bytes | Throws CryptoException | P0 |
| **UT-21** | `test_decrypt_returns_plaintext` | decrypt(cipher, nonce, tag, key) | Returns original plaintext | P0 |
| **UT-22** | `test_decrypt_empty_ciphertext` | decrypt("", nonce, tag, key) for empty encrypt | Returns "" | P0 |
| **UT-23** | `test_decrypt_unicode_plaintext` | Roundtrip with "🔐🔑🗝️" | UTF-8 preserved | P0 |
| **UT-24** | `test_decrypt_wrong_key` | Decrypt with different key | Throws CryptoException (tag fail) | P0 |
| **UT-25** | `test_decrypt_tampered_ciphertext` | Flip 1 bit in ciphertext | Throws CryptoException (tag fail) | P0 |
| **UT-26** | `test_decrypt_tampered_tag` | Flip 1 bit in tag | Throws CryptoException (tag fail) | P0 |
| **UT-27** | `test_decrypt_wrong_nonce` | Decrypt with different nonce | Throws CryptoException (tag fail) | P0 |
| **UT-28** | `test_decrypt_invalid_hex_ciphertext` | Invalid hex input | Throws CryptoException | P0 |
| **UT-29** | `test_decrypt_invalid_hex_nonce` | Invalid hex input | Throws CryptoException | P0 |
| **UT-30** | `test_decrypt_invalid_hex_tag` | Invalid hex input | Throws CryptoException | P0 |
| **UT-31** | `test_decrypt_wrong_nonce_length` | Nonce != 24 chars | Throws CryptoException | P0 |
| **UT-32** | `test_decrypt_wrong_tag_length` | Tag != 32 chars | Throws CryptoException | P0 |
| **UT-33** | `test_encrypt_decrypt_roundtrip` | Roundtrip test: A → encrypt → decrypt → A | Plaintext matches | P0 |
| **UT-34** | `test_hashPassword_matches_derivedKey` | hashPassword(...) vs deriveMasterKey(...) | Hex match | P0 |
| **UT-35** | `test_encrypt_decrypt_performance_cumulative` | Argon2id + decrypt < 200ms total | Duration < 200ms | P1 |

**Subtotal: ~35 Unit Tests**

### 10.2 Integration Tests (Entry + Encryption)

| Test ID | Test Name | Scenario | Expected | Priority |
|---------|-----------|----------|----------|----------|
| **IT-1** | `test_create_protected_entry_stores_encrypted` | Create entry with requiresAuth=true | Entry saved: secret=null, encrypted_secret!=null | P0 |
| **IT-2** | `test_create_protected_entry_stores_nonce_tag` | Same as above | nonce & tag not null, valid hex | P0 |
| **IT-3** | `test_create_unprotected_entry_unchanged` | Create with requiresAuth=false | Entry saved: secret=plaintext, encrypted_secret=null | P0 |
| **IT-4** | `test_view_protected_entry_requires_decrypt` | Load protected entry | secret field is null (not decrypted) | P0 |
| **IT-5** | `test_decrypt_protected_entry_retrieves_plaintext` | Decrypt with correct key | Plaintext matches original | P0 |
| **IT-6** | `test_decrypt_protected_entry_wrong_key_fails` | Decrypt with wrong key | CryptoException thrown | P0 |
| **IT-7** | `test_edit_protected_entry_updates_secret` | Edit secret of protected entry | New secret encrypted, new nonce | P0 |
| **IT-8** | `test_edit_protected_entry_toggle_off_stores_plaintext` | Edit: toggle protection OFF | secret=plaintext, encrypted_secret=null | P0 |
| **IT-9** | `test_search_returns_protected_entries` | Search for text in protected entry | Entry returned in results, secret masked | P0 |
| **IT-10** | `test_search_performance_with_protected_entries` | Search 100 entries (50% protected) | < 200 ms | P0 |
| **IT-11** | `test_protected_entry_shows_locked_indicator` | UI reads requiresAuth=true | Indicator shown (🔒) | P1 |
| **IT-12** | `test_migration_v1_to_v2_adds_columns` | Run migration on Phase 1 DB | New columns exist | P0 |
| **IT-13** | `test_migration_v1_to_v2_preserves_data` | Migrate, check old entries | All old entries still readable | P0 |
| **IT-14** | `test_master_password_config_table_created` | Check table after migration | Table exists with 0 rows | P0 |
| **IT-15** | `test_multiple_protected_entries_same_password` | Create 3 entries with same master password | All decrypt with same key | P0 |
| **IT-16** | `test_protected_entry_different_nonce_per_entry` | Create 2 entries with same plaintext | Different nonces for each | P0 |

**Subtotal: ~16 Integration Tests**

### 10.3 Provider Tests (Riverpod)

| Test ID | Test Name | Scenario | Expected | Priority |
|---------|-----------|----------|----------|----------|
| **PT-1** | `test_masterPasswordProvider_initial_state_null` | Create provider | State is null | P0 |
| **PT-2** | `test_masterPasswordProvider_setMasterPassword` | Call setMasterPassword(password) | State becomes Uint8List(32) | P0 |
| **PT-3** | `test_masterPasswordProvider_setMasterPassword_same_twice` | Set same password twice | Both calls succeed, same key | P0 |
| **PT-4** | `test_masterPasswordProvider_clearMasterPassword` | Set, then clear | State becomes null | P0 |
| **PT-5** | `test_masterPasswordProvider_isMasterPasswordSet` | Check with/without key | Returns bool correctly | P0 |
| **PT-6** | `test_masterPasswordProvider_empty_password_throws` | setMasterPassword("") | Throws AuthException | P0 |
| **PT-7** | `test_unlockedEntriesProvider_initial_state_empty` | Create provider | State is Set() | P0 |
| **PT-8** | `test_unlockedEntriesProvider_markUnlocked_adds_id` | markUnlocked("entry-1") | State contains "entry-1" | P0 |
| **PT-9** | `test_unlockedEntriesProvider_markUnlocked_multiple` | Mark 3 entries | State contains all 3 IDs | P0 |
| **PT-10** | `test_unlockedEntriesProvider_autoClear_after_30s` | Mark, wait 30s | Entry removed from state | P0 |
| **PT-11** | `test_unlockedEntriesProvider_autoClear_reset` | Mark, wait 20s, mark again, wait 10s | Entry still in state (timer reset) | P0 |
| **PT-12** | `test_entryAuthServiceProvider_is_singleton` | Get provider twice | Same instance | P0 |

**Subtotal: ~12 Provider Tests**

### 10.4 Widget Tests (UI)

| Test ID | Test Name | Scenario | Expected | Priority |
|---------|-----------|----------|----------|----------|
| **WT-1** | `test_entryDetailView_shows_reveal_button_if_protected` | Open protected entry | [🔒 Reveal Secret] button shown | P1 |
| **WT-2** | `test_entryDetailView_hides_secret_if_protected` | Open protected entry | Secret not visible as plaintext | P1 |
| **WT-3** | `test_entryDetailView_shows_secret_if_unprotected` | Open unprotected entry | Secret visible as plaintext | P1 |
| **WT-4** | `test_revealSecretSheet_opens_on_button_click` | Click [Reveal] button | Bottom sheet appears | P1 |
| **WT-5** | `test_revealSecretSheet_password_input_visible` | Open reveal sheet | Password input field shown | P1 |
| **WT-6** | `test_revealSecretSheet_unlock_button_visible` | Open reveal sheet | "Unlock & Reveal" button shown | P1 |
| **WT-7** | `test_revealSecretSheet_decrypt_on_unlock_success` | Correct password → Unlock | Secret plaintext displayed | P1 |
| **WT-8** | `test_revealSecretSheet_error_on_wrong_password` | Wrong password → Unlock | Error message shown | P1 |
| **WT-9** | `test_revealSecretSheet_autohide_30s` | Secret revealed → wait 30s | Secret hidden, button shown again | P1 |
| **WT-10** | `test_revealSecretSheet_cancel_closes_sheet` | Click Cancel | Sheet closes, secret still hidden | P1 |
| **WT-11** | `test_createEntryForm_protect_toggle_visible` | Open create form | "Protect this entry?" toggle shown | P1 |
| **WT-12** | `test_createEntryForm_protect_toggle_off_by_default` | Open create form | Toggle is OFF | P1 |
| **WT-13** | `test_createEntryForm_protect_toggle_on_shows_setup` | Toggle ON (first time) | Master password setup dialog shown | P1 |
| **WT-14** | `test_masterPasswordSetupDialog_inputs_visible` | Open setup dialog | Password + Confirm inputs shown | P1 |
| **WT-15** | `test_masterPasswordSetupDialog_set_button_visible` | Open setup dialog | "Set & Protect" button shown | P1 |
| **WT-16** | `test_masterPasswordSetupDialog_success_on_matching` | Enter matching passwords → Set | Dialog closes, entry saved | P1 |
| **WT-17** | `test_masterPasswordSetupDialog_error_on_mismatch` | Enter non-matching passwords → Set | Error shown, not saved | P1 |
| **WT-18** | `test_masterPasswordSetupDialog_cancel_discards` | Click Cancel | Dialog closes, no entry saved | P1 |

**Subtotal: ~18 Widget Tests**

### 10.5 Security-Specific Tests

| Test ID | Test Name | Scenario | Expected | Priority |
|---------|-----------|----------|----------|----------|
| **ST-1** | `test_nonce_uniqueness_100_encrypts` | Encrypt 100x, same plaintext | 100 unique nonces (0 collisions) | P0 |
| **ST-2** | `test_gcm_tag_prevents_tampering_1bit` | Flip 1 bit in ciphertext | Decrypt fails (tag invalid) | P0 |
| **ST-3** | `test_gcm_tag_prevents_tampering_all_bits` | Flip all bits in ciphertext | Decrypt fails (tag invalid) | P0 |
| **ST-4** | `test_gcm_tag_prevents_tampering_in_tag` | Flip 1 bit in tag | Decrypt fails (tag invalid) | P0 |
| **ST-5** | `test_master_key_not_in_logs` | Encrypt/decrypt, check logs | No plaintext key logged | P0 |
| **ST-6** | `test_plaintext_secret_not_in_logs` | Encrypt/decrypt, check logs | No plaintext secret logged | P0 |
| **ST-7** | `test_master_password_not_in_logs` | Set password, check logs | No plaintext password logged | P0 |
| **ST-8** | `test_salt_randomness_distribution` | Generate 1000 salts | Uniform distribution (statistical test) | P1 |
| **ST-9** | `test_nonce_randomness_distribution` | Generate 1000 nonces | Uniform distribution (statistical test) | P1 |

**Subtotal: ~9 Security Tests**

### 10.6 Total Test Count

```
Unit Tests:        ~35 tests
Integration Tests: ~16 tests
Provider Tests:    ~12 tests
Widget Tests:      ~18 tests
Security Tests:    ~9 tests
──────────────────────────────
TOTAL:             ~90 tests
```

**Target: ≥ 80% code coverage for critical paths (encrypt, decrypt, key derivation, providers)**

---

## 11. Acceptance Scenarios

### Scenario 1: Create and View Protected Entry

**Given:** User has Taúl app open, no master password set

**When:**
1. User creates new entry (title="API Key", type="password", secret="sk_live_123456")
2. User toggles "Protect this entry?" ON
3. App shows master password setup dialog
4. User enters password "MyMasterPassword" and confirms
5. User clicks "Set & Protect"

**Then:**
- master_password_config table has 1 row (hash + salt stored)
- Entry saved with: requiresAuth=true, secret=null, encrypted_secret!=null, cipherNonce!=null, cipherTag!=null
- masterPasswordProvider.state has derivedKey (32 bytes)
- Success toast: "Entry protected ✓"

**And When:** User later opens entry detail view

**Then:**
- Secret area shows "[🔒 Reveal Secret]" button
- No plaintext visible
- Clicking button opens bottom sheet with password input

**And When:** User enters correct password and clicks "Unlock & Reveal"

**Then:**
- Sheet closes
- Secret displays in plaintext: "sk_live_123456"
- "Auto-hides in 30 seconds" message shown
- After 30 seconds: secret hides, button shows again

---

### Scenario 2: Wrong Master Password

**Given:** User has protected entry, master password set

**When:** User opens entry, clicks [Reveal], enters WRONG password, clicks "Unlock & Reveal"

**Then:**
- Error shown: "Wrong password, try again"
- No plaintext displayed
- Sheet remains open for retry
- No exception thrown to user

---

### Scenario 3: Search Protected Entries

**Given:** User has entries (some protected, some not)
- Entry A: unprotected, title="Twitter Account"
- Entry B: protected, title="My Secret", secret="super_secret_token"

**When:** User searches for "secret"

**Then:**
- Results show both entries
- Entry A: secret plaintext visible (unprotected)
- Entry B: secret shows "[🔒 Protected - Reveal to View]"
- Search completes in < 200 ms

**And When:** User clicks Entry B

**Then:** Flows to Scenario 1 (reveal secret)

---

### Scenario 4: Toggle Protection Off

**Given:** User has protected entry

**When:** User edits entry, toggles "Protect this entry?" OFF, saves

**Then:**
- Entry updated: requiresAuth=false, secret=plaintext, encrypted_secret=null
- Ciphertext erased from DB (no recovery)

**And When:** User views entry again

**Then:**
- Secret shows in plaintext (no [Reveal] button)
- Normal unprotected entry behavior

---

### Scenario 5: Second Protected Entry (Master Password Already Set)

**Given:** User created one protected entry; master password set

**When:** User creates second entry with protection ON

**Then:**
- Master password setup dialog NOT shown
- App checks if derivedKey in memory
  - If YES: directly encrypt and save
  - If NO: prompt for password (bottom sheet), then encrypt and save
- New entry encrypted with same master password
- Both entries use same derived key for encrypt/decrypt

---

### Scenario 6: Database Migration (Phase 1 → Phase 2)

**Given:** User upgrades from Phase 1 to Phase 2

**When:** App starts (migration runs automatically)

**Then:**
- All Phase 1 entries remain in DB (unchanged)
- 4 new columns added: requires_auth (default false), encrypted_secret (null), cipherNonce (null), cipherTag (null)
- master_password_config table created (empty)
- FTS5 table unchanged
- All Phase 1 entries still searchable, readable, editable
- No data loss

---

### Scenario 7: Edit Protected Entry Secret

**Given:** User has protected entry with secret="old_secret"

**When:** User edits entry, changes secret to "new_secret", saves

**Then:**
- New secret encrypted with same master password
- New nonce generated (unique)
- Old encrypted_secret, cipherNonce, cipherTag replaced with new values
- Old plaintext "old_secret" never in logs

---

### Scenario 8: Delete Protected Entry

**Given:** User has protected entry

**When:** User deletes entry (confirm deletion)

**Then:**
- Entry removed from DB (including encrypted_secret, nonce, tag)
- FTS5 auto-syncs (entry removed from virtual table)
- No recovery possible (by design)

---

### Scenario 9: Tampered Ciphertext

**Given:** User has protected entry; attacker modifies encrypted_secret in DB (1 bit flip)

**When:** User tries to decrypt entry with correct password

**Then:**
- GCM tag verification fails
- CryptoException thrown
- Error shown: "Secret corrupted (tampering detected)"
- No plaintext returned
- Entry remains in DB (not deleted)

---

### Scenario 10: Master Password Forgotten

**Given:** User forgets master password; has protected entries

**When:** User tries to reveal protected entry, enters wrong password multiple times

**Then:**
- Each attempt shows "Wrong password, try again"
- No lockout (by design, Phase 2.1)
- User can retry indefinitely

**And No Recovery:** No recovery mechanism (Phase 2.1 feature; for now, user must know password)

---

## 12. Performance Requirements

| Operation | Specification | Notes |
|-----------|---------------|-------|
| **Argon2id KDF** | 150-250 ms on modern phone | Acceptable for initial setup; user sees progress |
| **Encrypt (100 bytes)** | < 10 ms | Typical entry secret size |
| **Decrypt (100 bytes)** | < 10 ms | Typical entry secret size |
| **Decrypt (10 KB)** | < 50 ms | Larger secret |
| **Total unlock (password input → plaintext display)** | < 200 ms | Includes KDF if not cached |
| **FTS5 search (no decrypt)** | < 200 ms | MUST NOT degrade from Phase 1 |
| **Entry creation (with encryption)** | < 500 ms | Including encrypt + DB save |
| **Nonce generation** | < 1 ms | Random.secure() is fast |
| **Salt generation** | < 1 ms | Random.secure() is fast |

**Target Devices:**
- Low-end Android (Snapdragon 632 or equivalent): 250-400 ms for Argon2id
- Mid-range Android (Snapdragon 855 or equivalent): 150-250 ms for Argon2id
- Modern iOS (A12 or later): 100-200 ms for Argon2id

---

## 13. Dependencies (Exact Versions)

```yaml
dependencies:
  # Existing (Phase 1)
  flutter:
    sdk: flutter
  riverpod: ^2.4.0
  drift: ^2.13.0
  go_router: ^10.2.0
  
  # NEW for Phase 2
  cryptography: ^2.7.0      # AES-GCM, Argon2id (pure Dart)
  pointycastle: ^3.10.0    # Backup crypto primitives (optional fallback)

dev_dependencies:
  # Existing
  flutter_test:
    sdk: flutter
  test: ^1.24.0
  
  # NEW for Phase 2 (optional, for testing)
  mockito: ^5.4.0
```

**Crypto Library Rationale:**
- `cryptography`: Pure Dart, no native deps, good performance, well-maintained
- `pointycastle`: Optional backup (pure Dart, more features, slightly older)
- NO `flutter_secure_storage` (hash in DB is sufficient)
- NO platform-specific code (all Dart)

---

## 14. Documentation Requirements

### 14.1 Deliverables

1. **SECURITY.md** (new file)
   - Encryption spec
   - Key derivation spec
   - Threat model
   - Mitigations
   
2. **CONTRIBUTING.md** update
   - Crypto guidelines
   - Logging hygiene
   - Testing requirements

3. **Code Comments**
   - Inline comments on all crypto operations
   - Explain why (not just what)

4. **README.md** section
   - User-facing: "How to protect entries"
   - Developer: "Building secure features"

---

## 15. Success Criteria (Checklist)

### Functional

- [ ] User can create entry with `requiresAuth=true`
- [ ] First protection prompts master password setup (one-time)
- [ ] Master password stored as Argon2id hash (not plaintext)
- [ ] EntryDetailView shows [🔒 Reveal Secret] button for protected entries
- [ ] Click [Reveal] → password input → decrypt → plaintext → auto-hide 30s
- [ ] Unprotected entries work normally (no change from Phase 1)
- [ ] All entry types can be protected (`note`, `password`, `secret`, `url`, etc.)
- [ ] Search returns protected entries with 🔒 indicator
- [ ] Search performance < 200 ms (same as Phase 1)
- [ ] Migration v1 → v2 preserves all Phase 1 data
- [ ] Edit protected entry re-encrypts with new nonce
- [ ] Toggle protection OFF decrypts and stores plaintext
- [ ] Delete protected entry removes ciphertext from DB

### Security

- [ ] AES-256-GCM with proper mode (not CBC, not ECB)
- [ ] Argon2id(t=2, m=65536, p=1) exactly
- [ ] Nonce: 12 bytes random (Random.secure), unique per encrypt
- [ ] GCM tag: 16 bytes, verified before decrypt
- [ ] Master password NEVER logged
- [ ] Master password NEVER persisted
- [ ] Derived key in memory only (volatile)
- [ ] Plaintext secret NEVER logged
- [ ] GCM tag validation is atomic (no partial plaintext on failure)
- [ ] Nonce uniqueness: 100+ encrypts → 100+ unique nonces

### Non-Functional

- [ ] Code coverage ≥ 80% (critical paths 100%)
- [ ] All 90+ tests passing
- [ ] Performance: Argon2id < 250 ms on mid-range phone
- [ ] Performance: Total unlock flow < 200 ms
- [ ] Performance: Search < 200 ms (no degradation)
- [ ] Drift migration script tested on v1 database
- [ ] No compile errors or warnings
- [ ] Documentation complete (SECURITY.md, inline comments)
- [ ] Error handling comprehensive (all exceptions mapped to user messages)

---

## 16. Assumptions & Dependencies

### 16.1 Assumptions

1. **User has one master password per app installation** (not per entry, not per device)
2. **Master password is strong** (user responsibility; no policy enforcement in Phase 2)
3. **Device is trusted** (once unlocked, attacker has access to derived key in RAM)
4. **No session timeout** (by design; derived key cleared only on app exit or manual clear)
5. **Nonce uniqueness is guaranteed by Random.secure()** (no external state needed)
6. **Drift migrations are one-way** (no rollback planned)
7. **SQLite is available** (Phase 1 dependency; unchanged)
8. **Riverpod is the state management** (Phase 1 dependency; unchanged)

### 16.2 Dependencies

1. **cryptography ^2.7.0** (new)
2. **Riverpod ^2.4.0** (existing)
3. **Drift ^2.13.0** (existing, for migrations)
4. **Flutter SDK** (existing)

### 16.3 External Constraints

1. **Platform:** iOS & Android (no web, desktop pending Phase 3)
2. **Min SDK:** iOS 11+, Android 5.0+
3. **Flutter:** 3.10+

---

## 17. Known Risks & Mitigations

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| **Argon2id too slow** | Low | Medium | Parámetros t=2 tested; fallback to t=1 if needed |
| **Nonce collision** | Very Low | Critical | Random.secure() guaranteed unique; verify in 100+ test |
| **GCM tag bypass** | Negligible | Critical | Use battle-tested `cryptography` library, not custom |
| **Plaintext in logs** | Low | High | Code review, logging guidelines, security tests |
| **Database migration corruption** | Very Low | Critical | Test on real Phase 1 database; backup recommended |
| **Derived key memory leak** | Very Low | Medium | Uint8List volatile; cleared on app exit |
| **Wrong password accepted** | Negligible | Critical | GCM tag verification atomic; no false positives |
| **User forgets master password** | Medium | High | Document warning; Phase 2.1 adds recovery |

---

## 18. Change Summary (vs Phase 1)

| Component | Phase 1 | Phase 2 | Impact |
|-----------|---------|---------|--------|
| **Entry model** | No protection | `requiresAuth` flag + encrypted fields | Schema change + migration required |
| **Database** | 4 columns | +4 columns + 1 table | Migration v1→v2 |
| **Encryption** | None | AES-256-GCM per entry | New crypto layer |
| **Key derivation** | None | Argon2id from password | New KDF layer |
| **UI: Create** | Simple form | + protect toggle + setup dialog | UI enhancement |
| **UI: View** | Show secret | [Reveal] button if protected | UI enhancement |
| **UI: Edit** | Simple form | Handle encrypted secret | UI enhancement |
| **UI: Search** | FTS5 results | + masking for protected entries | Cosmetic change |
| **Performance** | FTS5 < 200ms | FTS5 < 200ms (unchanged) | No degradation |
| **Dependencies** | ~30 packages | +2 new (cryptography, pointycastle) | Minimal overhead |
| **Code coverage** | 70% | 80%+ | Requirement increase |

---

## 19. Glossary

| Term | Definition |
|------|-----------|
| **AEAD** | Authenticated Encryption with Associated Data (mode providing both encryption and authentication) |
| **AES-GCM** | Advanced Encryption Standard in Galois/Counter Mode |
| **Argon2id** | Password-based key derivation function with memory-hard defense |
| **Ciphertext** | Encrypted data (output of encryption) |
| **Derived Key** | Key generated from password via KDF |
| **GCM tag** | Authentication tag proving authenticity and detecting tampering |
| **KDF** | Key Derivation Function (password → key) |
| **Nonce** | Number used once; IV for GCM mode |
| **Plaintext** | Unencrypted data |
| **Random.secure()** | Cryptographically secure random number generator |
| **Salt** | Random value added to password before KDF (prevents rainbow tables) |
| **Uint8List** | Unsigned 8-bit integer list (byte array in Dart) |

---

## 20. Appendix: Reference Implementations

### A1: Conceptual Encrypt Flow

```
plaintext ("MySecret") + derivedKey (32 bytes)
  ↓
NONCE = Random.secure(12 bytes)
  ↓
AES-256-GCM.encrypt(plaintext, key, nonce)
  ↓
OUTPUT: (ciphertext, tag)
  ↓
EncryptionResult {
  encryptedSecret: hex(ciphertext),
  nonce: hex(NONCE),
  tag: hex(tag)
}
  ↓
DB STORE:
  encrypted_secret = hex(ciphertext)
  cipher_nonce = hex(NONCE)
  cipher_tag = hex(tag)
```

### A2: Conceptual Decrypt Flow

```
DB LOAD:
  encrypted_secret = "K9lP2..."
  cipher_nonce = "n1n2n3..."
  cipher_tag = "t1t2t3..."
  
password ("MyPassword") + derivedKey (from masterPasswordProvider.state)
  ↓
ciphertext = hex.decode(encrypted_secret)
nonce = hex.decode(cipher_nonce)
tag = hex.decode(cipher_tag)
  ↓
AES-256-GCM.decrypt(ciphertext, key, nonce, tag)
  ↓
GCM tag verification (atomic)
  ├─ FAIL → CryptoException thrown (wrong key, tampering, etc.)
  └─ OK → ciphertext decrypted
  ↓
plaintext = utf8.decode(decrypted_bytes)
  ↓
plaintext ("MySecret") returned to UI
```

### A3: Master Password Setup Flow

```
User Input:
  password1 = "MyMasterPassword"
  password2 = "MyMasterPassword"
  
VALIDATE:
  ├─ Both non-empty? ✓
  └─ Match? ✓
  
GENERATE:
  salt = Random.secure(16 bytes) → hex(salt)
  
DERIVE & HASH:
  derivedKey = Argon2id(password, salt) → Uint8List(32)
  hash = hex(derivedKey)
  
DB STORE:
  INSERT master_password_config:
    id=1
    password_hash_argon2=hash
    salt_hex=salt
    created_at=now()
    updated_at=now()
    
MEMORY:
  masterPasswordProvider.state = derivedKey
  
SUCCESS
```

---

## 21. Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 2.0 | 2025 | Architecture Team | Initial SDD spec (Phase 2) |

---

## 22. Sign-Off

**Specification Status:** ✅ APPROVED FOR IMPLEMENTATION

**Reviewed By:**
- [ ] Tech Lead
- [ ] Architect
- [ ] Security Officer

---

**End of Specification**

**Document ID:** `sdd/phase-2-entry-protection-optional/spec`  
**Format:** Markdown (portable, VCS-friendly)  
**Audience:** Developers, QA, Security Review  
**Next Phase:** sdd-design (architecture diagrams, threat model details)
