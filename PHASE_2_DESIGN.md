# 🏗️ Design SDD – Fase 2: Per-Entry Protection

**Taúl — Almacenamiento Personal Minimalista, Rápido y Seguro**

**Versión:** 2.0-Phase2-Design  
**Fecha:** 2025  
**Estado:** ✅ DESIGN COMPLETE  
**Responsable:** Architecture  
**Effort:** 20 horas (1 semana, 1 person)  
**Risk Level:** 🟢 LOW

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [Data Flow Diagrams](#data-flow-diagrams)
4. [Component Architecture](#component-architecture)
5. [State Machine (Riverpod)](#state-machine-riverpod)
6. [Security Architecture](#security-architecture)
7. [Implementation Approach](#implementation-approach)
8. [Error Handling](#error-handling)
9. [Database Migration Strategy](#database-migration-strategy)
10. [Performance Considerations](#performance-considerations)
11. [Testing Architecture](#testing-architecture)
12. [Architectural Decision Records](#architectural-decision-records)

---

## Executive Summary

**Design Approach:** Layer-based architecture with per-entry encryption, Riverpod state management, and Drift ORM. Single contraseña maestra (Argon2id derived) protects multiple entries via AES-256-GCM encryption. Zero global friction — users only authenticate when revealing protected secrets.

**Key Decisions:**
- ✅ **Per-entry protection** (not global vault) → Zero friction on search/browse
- ✅ **Riverpod state for masterKey** → In-memory, volatile, cleared on app exit
- ✅ **AES-256-GCM + Argon2id** → NIST-approved, production-ready
- ✅ **Sync-safe design** → All secrets pre-encrypted before Phase 3 sync
- ✅ **No biometrics Phase 2** → Manual password only, prepare for Phase 2.1

---

## Architecture Overview

### 2.1 Seven-Layer Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 7: Presentation Layer (UI)                               │
│ ├─ EntryDetailView (+ [Reveal Secret] button)                 │
│ ├─ EntryCreateEditForm (+ Protect Toggle)                     │
│ └─ MasterPasswordSetupDialog                                  │
└─────────────────────────────────────────────────────────────────┘
                          ↓ Riverpod Inject
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 6: State Management (Riverpod)                           │
│ ├─ masterPasswordProvider (Uint8List? derivedKey)             │
│ ├─ unlockedEntriesProvider (Set<int> IDs)                     │
│ └─ entryAuthServiceProvider (Singleton)                       │
└─────────────────────────────────────────────────────────────────┘
                          ↓ Provider calls
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 5: Domain Logic (Use Cases)                              │
│ ├─ EntryAuthUseCase (setMasterPassword, revealSecret)         │
│ ├─ EntryCreateUseCase (createProtected, createPlain)          │
│ └─ SearchUseCase (searchWithProtection)                       │
└─────────────────────────────────────────────────────────────────┘
                          ↓ Service calls
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 4: Infrastructure Services                               │
│ ├─ EntryAuthService (encrypt/decrypt/derive)                  │
│ ├─ EntryRepository (CRUD on Entry + config)                   │
│ └─ MasterPasswordRepository (Singleton config table)          │
└─────────────────────────────────────────────────────────────────┘
                          ↓ Drift ORM calls
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 3: Data Access Layer (Drift ORM)                         │
│ ├─ AppDatabase (migrations, queries)                          │
│ ├─ $EntriesTable (schema + handlers)                          │
│ └─ $MasterPasswordConfigTable (schema + handlers)             │
└─────────────────────────────────────────────────────────────────┘
                          ↓ SQLite driver
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 2: Persistence Layer (SQLite)                            │
│ ├─ entries table (v1 cols + 4 new cols)                       │
│ └─ master_password_config table (singleton)                   │
└─────────────────────────────────────────────────────────────────┘
                          ↓ In-memory state
┌─────────────────────────────────────────────────────────────────┐
│ LAYER 1: Runtime Memory Layer                                  │
│ ├─ masterPasswordProvider.state (Uint8List derivedKey)        │
│ └─ unlockedEntriesProvider.state (Set<int>)                   │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Dependency Injection Graph (Riverpod)

```
entryAuthServiceProvider (Singleton)
  │
  ├─→ masterPasswordProvider (StateNotifier<Uint8List?>)
  │    └─ Used by: RevealSecretSheet, EntryDetailView
  │
  ├─→ unlockedEntriesProvider (StateNotifier<Set<int>>)
  │    └─ Used by: EntryDetailView (show 🔒 icon)
  │
  └─→ entryRepositoryProvider
       ├─ Used by: CreateEntryUseCase
       ├─ Used by: SearchUseCase
       └─ Used by: EditEntryUseCase
```

### 2.3 Separation of Concerns

| Layer | Responsibility | Example |
|-------|---|---|
| **Presentation** | Render UI, collect input | EntryDetailView.build() |
| **State Mgmt** | Hold app state, invalidate | masterPasswordProvider.state |
| **Domain** | Business logic, workflows | RevealSecretUseCase.call() |
| **Infrastructure** | External integrations | EntryAuthService.decrypt() |
| **Data Access** | DB queries via ORM | $EntriesTable.select() |
| **Persistence** | SQLite read/write | SQLite driver |
| **Memory** | Runtime state | Riverpod StateNotifier |

---

## Data Flow Diagrams

### 3.1 Setup Master Password (First Time) — 8 Steps

**Trigger:** User toggles "Protect this entry?" ON for first time

```
  STEP 1: User creates entry
     ↓ Toggles "Protect this entry?" → ON
     ↓
  STEP 2: isFirstProtection check
     ├─ Query: SELECT * FROM master_password_config WHERE id = 1
     ├─ Result: NO row found
     ├─ Decision: isFirstProtection = true
     ↓
  STEP 3: Show MasterPasswordSetupDialog
     ├─ Input: Password field (masked)
     ├─ Input: Confirm field (masked)
     ├─ User clicks: "Set & Protect"
     ↓
  STEP 4: Validate password match
     ├─ if (password != confirm) → ERROR: "Passwords don't match"
     ├─ if (password.length < 8) → ERROR: "Min 8 chars"
     ├─ if (password.length > 1000) → ERROR: "Max 1000 chars"
     ├─ PASS → Continue
     ↓
  STEP 5: Generate salt + derive key
     ├─ salt = generateSalt() → 16 random bytes → hex(32 chars)
     ├─ derivedKey = await deriveMasterKey(password, salt)
     │  └─ Argon2id(password, salt, t=2, m=65536, p=1)
     │  └─ Duration: 150-250ms → async/await to prevent UI freeze
     ├─ Result: Uint8List(32 bytes)
     ↓
  STEP 6: Hash password for storage
     ├─ passwordHash = await hashPassword(password, salt)
     │  └─ Argon2id(password, salt, t=2, m=65536, p=1) → hex(64 chars)
     ↓
  STEP 7: Store master password config
     ├─ INSERT INTO master_password_config (password_hash_argon2, salt_hex, created_at, updated_at)
     │           VALUES (?, ?, NOW, NOW)
     ├─ id = 1 (singleton)
     ↓
  STEP 8: Store derivedKey in Riverpod
     ├─ masterPasswordProvider.state = derivedKey
     └─ Encrypted entry will use this key → continue to Step 3.2
```

### 3.2 Create Protected Entry — 6 Steps

**Trigger:** User submits form with requiresAuth=true

```
  STEP 1: Get masterKey from Riverpod
     ├─ if (masterPasswordProvider.state == null)
     │  └─ ERROR: "Master password not set" (shouldn't happen)
     ├─ derivedKey = masterPasswordProvider.state
     ↓
  STEP 2: Encrypt secret
     ├─ plaintext = entry.secret (e.g., "MyPassword123!")
     ├─ result = await entryAuthService.encrypt(plaintext, derivedKey)
     │  ├─ nonce = Random.secure(12 bytes) → hex(24 chars)
     │  ├─ Cipher: AES-256-GCM encrypt(plaintext, derivedKey, nonce)
     │  ├─ Tag: Extract 16-byte GCM authentication tag → hex(32 chars)
     │  └─ Returns: EncryptionResult{encryptedSecret, nonce, tag}
     ↓
  STEP 3: Prepare entry DTO
     ├─ entry.requiresAuth = true
     ├─ entry.secret = null (encrypted, moved to encryptedSecret)
     ├─ entry.encryptedSecret = result.encryptedSecret (hex)
     ├─ entry.cipherNonce = result.nonce (hex)
     ├─ entry.cipherTag = result.tag (hex)
     ├─ entry.content = unchanged
     ├─ entry.type = unchanged (all types can be protected)
     ↓
  STEP 4: Save to database
     ├─ INSERT INTO entries (topic_key, type, title, secret, content,
     │           requires_auth, encrypted_secret, cipher_nonce, cipher_tag,
     │           created_at, updated_at)
     │        VALUES (?, ?, ?, NULL, ?, TRUE, ?, ?, ?, NOW, NOW)
     ↓
  STEP 5: Pop dialog
     ├─ Navigator.pop(context)
     ↓
  STEP 6: Invalidate providers
     ├─ ref.invalidate(entriesProvider)
     ├─ ref.invalidate(searchProvider) [if FTS5 search active]
     └─ UI rebuilds with updated entry list
```

### 3.3 View/Unlock Protected Entry — 9 Steps

**Trigger:** User taps on entry detail, clicks [🔒 Reveal Secret]

```
  STEP 1: Load entry from DB
     ├─ Query: SELECT * FROM entries WHERE id = ?
     ├─ Result: Entry{requiresAuth=true, encryptedSecret, cipherNonce, cipherTag, ...}
     ↓
  STEP 2: Check if already unlocked in session
     ├─ unlockedEntriesProvider.state.contains(entry.id)?
     ├─ YES → Jump to STEP 7 (show plaintext directly)
     ├─ NO → Continue
     ↓
  STEP 3: Show password input sheet
     ├─ RevealSecretSheet()
     ├─ Input: Password field (masked)
     ├─ Button: "Unlock"
     ↓
  STEP 4: Verify password hash
     ├─ Query: SELECT password_hash_argon2, salt_hex FROM master_password_config
     ├─ userHash = await hashPassword(userInput, salt_hex)
     ├─ if (userHash != password_hash_argon2)
     │  └─ ERROR: "Invalid password" → Stay in Step 3
     ├─ PASS → Continue
     ↓
  STEP 5: Derive key from password
     ├─ derivedKey = await deriveMasterKey(userInput, salt_hex)
     │  └─ Duration: 150-250ms → async/await
     ↓
  STEP 6: Decrypt secret
     ├─ ciphertext = entry.encryptedSecret
     ├─ nonce = entry.cipherNonce
     ├─ tag = entry.cipherTag
     ├─ plaintext = await entryAuthService.decrypt(ciphertext, nonce, tag, derivedKey)
     │  ├─ Validate nonce length = 24 hex chars (12 bytes)
     │  ├─ Validate tag length = 32 hex chars (16 bytes)
     │  ├─ Decode hex → bytes
     │  ├─ AES-256-GCM decrypt(ciphertext, nonce, tag, derivedKey)
     │  ├─ GCM tag verification ATOMIC → on failure throw CryptoException
     │  └─ UTF-8 decode → plaintext
     ├─ if CryptoException → ERROR: "Decryption failed (password wrong?)"
     ↓
  STEP 7: Display plaintext
     ├─ Show: plaintext in read-only field (font monospace)
     ├─ Show: Copy button (copy to clipboard)
     ├─ Show: Timer "30s remaining"
     ↓
  STEP 8: Mark as unlocked (session cache)
     ├─ unlockedEntriesProvider.add(entry.id)
     ├─ Schedule timer: after 30s → unlockedEntriesProvider.remove(entry.id)
     ↓
  STEP 9: Auto-hide after 30s
     ├─ Sheet auto-dismisses
     ├─ EntryDetailView UI updates (hides [Reveal], shows 🔒 icon)
     ├─ User can copy-paste during those 30s
     └─ If user manually dismisses earlier → timer also cleared
```

### 3.4 Search with Protection — 5 Steps

**Trigger:** User enters search query in SearchBar

```
  STEP 1: FTS5 search (unchanged)
     ├─ Query: SELECT * FROM entries WHERE title MATCH ? OR content MATCH ?
     │          OR encrypted_secret MATCH ? (if requiresAuth=true)
     ├─ Note: encrypted_secret contains garbage, but encrypted_secret of matching entry
     │         will be returned as blob
     ├─ Result: Entry[]{...requiresAuth=true, encryptedSecret, ...}
     ↓
  STEP 2: Filter results
     ├─ For each result:
     │  ├─ if (entry.requiresAuth == true) → Add 🔒 indicator
     │  └─ if (entry.requiresAuth == false) → No indicator
     ↓
  STEP 3: Display search results
     ├─ ListTile{
     │  ├─ Title: entry.title
     │  ├─ Subtitle: entry.content (first 100 chars)
     │  ├─ Trailing: (requiresAuth ? "🔒" : "")
     │  └─ onTap: → EntryDetailView (which triggers Step 3.3 if clicked [Reveal])
     ├─ }
     ↓
  STEP 4: User clicks result
     ├─ Navigator.push(EntryDetailView(entry.id))
     ↓
  STEP 5: Follow Step 3.3 (View/Unlock)
     └─ If entry.requiresAuth=true → Ask password
     └─ If entry.requiresAuth=false → Show directly
```

---

## Component Architecture

### 4.1 EntryAuthService (Core Service)

**File:** `lib/src/infrastructure/services/entry_auth_service.dart`

```dart
/// Single-responsibility service for encryption/decryption operations
class EntryAuthService {
  /// Generate random 16-byte salt (hex-encoded)
  String generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return values.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Derive 256-bit key from password using Argon2id KDF
  /// Duration: 150-250ms (async to prevent UI freeze)
  /// Throws: AuthException, CryptoException
  Future<Uint8List> deriveMasterKey(String password, String saltHex) async {
    // Validate inputs
    if (password.isEmpty) throw AuthException('Password cannot be empty');
    if (password.length > 10000) throw AuthException('Password too long');
    if (saltHex.length != 32) throw CryptoException('Salt must be 16 bytes (32 hex chars)');
    
    try {
      final salt = hex.decode(saltHex);
      // Use argon2id package: Argon2id(t=2, m=65536, p=1)
      final key = await Argon2id(
        iterations: 2,
        memory: 65536, // 64 MB
        parallelism: 1,
        length: 32, // 256 bits
      ).generate(password: password, salt: salt);
      return key.rawBytes;
    } catch (e) {
      throw CryptoException('Key derivation failed: $e');
    }
  }

  /// Encrypt plaintext with AES-256-GCM
  /// Returns: {encryptedSecret, nonce, tag} all hex-encoded
  /// Throws: CryptoException
  EncryptionResult encrypt(String plaintext, Uint8List derivedKey) {
    if (derivedKey.length != 32) throw CryptoException('Key must be 32 bytes');
    
    try {
      final random = Random.secure();
      final nonce = List<int>.generate(12, (i) => random.nextInt(256)); // 12 bytes
      
      // Use pointycastle/cryptography for AES-256-GCM
      final aes = AES(derivedKey, mode: GCMMode(nonce));
      final plainBytes = utf8.encode(plaintext);
      
      // Encrypt + Tag (16 bytes)
      final encrypted = aes.encrypt(plainBytes);
      // Extract tag (last 16 bytes from GCM output)
      final tag = encrypted.sublist(encrypted.length - 16);
      final ciphertext = encrypted.sublist(0, encrypted.length - 16);
      
      return EncryptionResult(
        encryptedSecret: hex.encode(ciphertext),
        nonce: hex.encode(nonce),
        tag: hex.encode(tag),
      );
    } catch (e) {
      throw CryptoException('Encryption failed: $e');
    }
  }

  /// Decrypt ciphertext with AES-256-GCM
  /// Verify GCM tag MANDATORY
  /// Throws: CryptoException on wrong password, tampering, invalid input
  Future<String> decrypt(
    String encryptedSecretHex,
    String nonceHex,
    String tagHex,
    Uint8List derivedKey,
  ) async {
    if (derivedKey.length != 32) throw CryptoException('Key must be 32 bytes');
    if (nonceHex.length != 24) throw CryptoException('Nonce must be 12 bytes (24 hex chars)');
    if (tagHex.length != 32) throw CryptoException('Tag must be 16 bytes (32 hex chars)');
    
    try {
      final ciphertext = hex.decode(encryptedSecretHex);
      final nonce = hex.decode(nonceHex);
      final tag = hex.decode(tagHex);
      
      // Concatenate ciphertext + tag for GCM verify
      final fullCiphertext = Uint8List.fromList([...ciphertext, ...tag]);
      
      // Use AES-256-GCM decrypt + verify
      final aes = AES(derivedKey, mode: GCMMode(nonce));
      final plainBytes = aes.decrypt(fullCiphertext);
      
      return utf8.decode(plainBytes);
    } catch (e) {
      throw CryptoException('Decryption failed (password wrong?): $e');
    }
  }

  /// Hash password for storage/verification
  Future<String> hashPassword(String password, String saltHex) async {
    if (password.isEmpty) throw AuthException('Password cannot be empty');
    if (saltHex.length != 32) throw CryptoException('Salt must be 16 bytes');
    
    try {
      final salt = hex.decode(saltHex);
      final hash = await Argon2id(
        iterations: 2,
        memory: 65536,
        parallelism: 1,
        length: 32,
      ).generate(password: password, salt: salt);
      return hex.encode(hash.rawBytes);
    } catch (e) {
      throw CryptoException('Hash failed: $e');
    }
  }
}

/// Result of encryption operation
class EncryptionResult {
  final String encryptedSecret; // hex-encoded ciphertext (no tag)
  final String nonce;            // hex-encoded 12-byte nonce
  final String tag;              // hex-encoded 16-byte GCM tag
  
  EncryptionResult({
    required this.encryptedSecret,
    required this.nonce,
    required this.tag,
  });
}

/// Base exception
abstract class EntryAuthException implements Exception {
  final String message;
  EntryAuthException(this.message);
  
  @override
  String toString() => '$runtimeType: $message';
}

class CryptoException extends EntryAuthException {
  CryptoException(String message) : super(message);
}

class AuthException extends EntryAuthException {
  AuthException(String message) : super(message);
}
```

### 4.2 Riverpod Providers Hierarchy

**File:** `lib/src/application/providers/entry_auth_providers.dart`

```dart
// ============= SINGLETON =============
final entryAuthServiceProvider = Provider((ref) => EntryAuthService());

// ============= STATE MANAGERS =============

/// Holds derived master key in memory (volatile)
/// Cleared on app exit or manual logout
final masterPasswordProvider = StateNotifierProvider<
    MasterPasswordNotifier,
    Uint8List?
>((ref) => MasterPasswordNotifier());

class MasterPasswordNotifier extends StateNotifier<Uint8List?> {
  MasterPasswordNotifier() : super(null);
  
  void setMasterPassword(Uint8List derivedKey) {
    state = derivedKey;
  }
  
  void clearMasterPassword() {
    state = null;
  }
  
  bool isMasterPasswordSet() => state != null;
}

/// Cache of unlocked entry IDs (for 30s timeout per entry)
/// Auto-clears after timeout
final unlockedEntriesProvider = StateNotifierProvider<
    UnlockedEntriesNotifier,
    Set<int>
>((ref) => UnlockedEntriesNotifier());

class UnlockedEntriesNotifier extends StateNotifier<Set<int>> {
  final Map<int, Timer> _timers = {};
  
  UnlockedEntriesNotifier() : super({});
  
  void addUnlockedEntry(int entryId) {
    state = {...state, entryId};
    
    // Clear any existing timer
    _timers[entryId]?.cancel();
    
    // Start new 30s timer
    _timers[entryId] = Timer(Duration(seconds: 30), () {
      removeUnlockedEntry(entryId);
    });
  }
  
  void removeUnlockedEntry(int entryId) {
    _timers[entryId]?.cancel();
    _timers.remove(entryId);
    state = state.where((id) => id != entryId).toSet();
  }
  
  bool isUnlocked(int entryId) => state.contains(entryId);
  
  void clearAll() {
    for (var timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    state = {};
  }
}

// ============= REPOSITORIES =============

final entryRepositoryProvider = Provider((ref) => EntryRepository(ref.watch(appDatabaseProvider)));

final masterPasswordConfigRepositoryProvider = Provider(
  (ref) => MasterPasswordConfigRepository(ref.watch(appDatabaseProvider)),
);
```

### 4.3 Entry Entity (Before/After Encryption)

```dart
@DataClassName('Entry')
class EntriesTable extends Table {
  // Phase 1 columns (unchanged)
  IntColumn get id => integer().autoIncrement()();
  TextColumn get topicKey => text()();
  TextColumn get type => text()(); // 'password', 'note', 'secret', 'url', etc.
  TextColumn get title => text()();
  TextColumn get secret => text().nullable()(); // NOW NULLABLE (encrypted → NULL)
  TextColumn get content => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  
  // ========== PHASE 2 NEW COLUMNS ==========
  BoolColumn get requiresAuth => boolean().withDefault(Constant(false))();
  TextColumn get encryptedSecret => text().nullable()(); // AES-256-GCM ciphertext (hex)
  TextColumn get cipherNonce => text().nullable()(); // 12 bytes → hex (24 chars)
  TextColumn get cipherTag => text().nullable()();    // 16 bytes → hex (32 chars)
  
  @override
  Set<Column> get primaryKey => {id};
  
  @override
  List<Set<Column>> get uniqueKeys => [
    {topicKey, type, title}, // Ensure uniqueness per topic
  ];
}

// Drift-generated class
class Entry extends DataClass implements Insertable<Entry> {
  // Phase 1
  final int? id;
  final String topicKey;
  final String type;
  final String title;
  final String? secret; // NULL if encrypted
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Phase 2
  final bool requiresAuth;
  final String? encryptedSecret;
  final String? cipherNonce;
  final String? cipherTag;
  
  // ===== INVARIANTS =====
  bool get isProtected => requiresAuth && encryptedSecret != null;
  bool get isPlaintext => !requiresAuth && secret != null;
  
  // Getters for display
  String get displaySecret {
    if (isProtected) return '[🔒 Protected]';
    return secret ?? '';
  }
}

// Phase 1: Entry { secret: "password123" }
// ↓ User clicks "Protect"
// Phase 2: Entry { 
//   secret: null,
//   requiresAuth: true,
//   encryptedSecret: "a1b2c3d4...", // 32-byte ciphertext hex
//   cipherNonce: "e5f6789...",      // 12-byte nonce hex
//   cipherTag: "0a1b2c3d..." // 16-byte tag hex
// }
```

### 4.4 MasterPasswordConfig Entity

```dart
@DataClassName('MasterPasswordConfig')
class MasterPasswordConfigTable extends Table {
  IntColumn get id => integer().primary(); // Always 1 (singleton)
  TextColumn get passwordHashArgon2 => text()(); // Argon2id hash hex (64 chars)
  TextColumn get saltHex => text()(); // 16 bytes random, hex (32 chars)
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

// Drift-generated
class MasterPasswordConfig extends DataClass {
  final int id; // 1
  final String passwordHashArgon2;
  final String saltHex;
  final DateTime createdAt;
  final DateTime updatedAt;
}

// Invariants:
// - 0 or 1 row (app enforces singleton)
// - saltHex: ONLY for KDF, never for encryption
// - passwordHashArgon2: NEVER used for encryption, ONLY verification
```

---

## State Machine (Riverpod)

### 5.1 masterPasswordProvider States

```
┌──────────────────┐
│                  │
│    NULL STATE    │
│ (no master key)  │
│                  │
└────────┬─────────┘
         │
         │ setMasterPassword(derivedKey: Uint8List)
         │
         ▼
┌──────────────────────────┐
│                          │
│  UNLOCKED STATE          │
│  (derivedKey in memory)  │
│                          │
│  Uint8List(32 bytes)     │
└────────┬─────────────────┘
         │
         │ clearMasterPassword()
         │ OR app terminated
         │
         ▼
┌──────────────────┐
│                  │
│    NULL STATE    │ ← Cycle repeats
│                  │
└──────────────────┘
```

**Transitions:**
- **NULL → UNLOCKED:** User enters correct password → deriveMasterKey → store in state
- **UNLOCKED → NULL:** User logs out OR app exits (widget disposal)
- **INVALID PASSWORD:** User enters wrong password → CryptoException → stay in NULL

### 5.2 unlockedEntriesProvider States

```
┌──────────────────────┐
│                      │
│  EMPTY SET STATE     │
│  Set<int> {}         │
│  (all entries locked)│
│                      │
└────────┬─────────────┘
         │
         │ addUnlockedEntry(entryId)
         │
         ▼
┌──────────────────────────────┐
│                              │
│  PARTIAL UNLOCK STATE        │
│  Set<int> {123, 456}         │
│  (some entries revealed)      │
│                              │
│  Timer(30s) on each entry    │
└────────┬─────────────────────┘
         │
         │ removeUnlockedEntry(entryId)
         │ OR timer fires
         │
         ▼
┌──────────────────────┐
│                      │
│  EMPTY SET STATE     │
│  Set<int> {}         │
│  (cycle repeats)     │
│                      │
└──────────────────────┘
```

**Invariants:**
- Each unlocked entry has a 30-second timer
- Concurrent unlocked entries are independent
- Timer auto-cancels on app termination

---

## Security Architecture

### 6.1 Key Derivation Flow

```
┌────────────────────────────────┐
│ User Master Password           │
│ (e.g., "MySecurePass2025!")    │
└────────────┬───────────────────┘
             │
             ▼
     ┌───────────────────┐
     │ UTF-8 Encode      │
     │ String → Bytes    │
     └───────┬───────────┘
             │
             ▼
┌────────────────────────────────────────┐
│ + Salt (16 random bytes, one-time)    │
│ Previously generated & stored in DB    │
└────────┬─────────────────────────────────┘
         │
         ▼
┌────────────────────────────────────────┐
│ ARGON2ID KDF                           │
│ - Time cost (t) = 2 iterations         │
│ - Memory cost (m) = 65536 KB (64 MB)   │
│ - Parallelism (p) = 1 thread           │
│ - Output length = 32 bytes (256 bits)  │
│ - Duration: 150-250ms (async)          │
│                                        │
│ NIST-approved, brute-force resistant   │
│ (165 billion iterations per second on  │
│  GPU still takes ~30 days per password)│
└────────┬─────────────────────────────┘
         │
         ▼
┌────────────────────────────────┐
│ Derived Master Key             │
│ Uint8List(32 bytes)            │
│ Stored in: Riverpod state      │
│ Lifetime: Session only (RAM)   │
│ Used for: AES-256 encryption   │
└────────────────────────────────┘
```

### 6.2 Encryption Flow (Per Secret)

```
┌─────────────────────────────┐
│ Plaintext Secret            │
│ (e.g., "AmazonPassword123") │
└────────┬────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│ UTF-8 Encode                │
│ String → Bytes              │
└────────┬────────────────────┘
         │
         ▼
     ┌────────────────────────┐
     │ Generate Nonce         │
     │ 12 random bytes        │
     │ (Random.secure())      │
     │ NEW FOR EVERY ENCRYPT  │
     └────────┬───────────────┘
             │
             ▼
┌─────────────────────────────────────────┐
│ AES-256-GCM ENCRYPT                     │
│ - Cipher: AES                           │
│ - Key: 256 bits (32 bytes, derivedKey) │
│ - Mode: GCM (Galois/Counter Mode)       │
│ - IV: 12-byte nonce                     │
│ - AAD: None (AEAD, no additional data)  │
│ - Duration: 2-5ms (< 10ms typical)      │
│                                         │
│ Output:                                 │
│ - Ciphertext: variable length           │
│ - Auth Tag: 16 bytes (128 bits)         │
└────────┬────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│ HEX ENCODE FOR STORAGE                   │
│                                          │
│ ciphertext (N bytes) → hex (2N chars)    │
│ nonce (12 bytes) → hex (24 chars)        │
│ tag (16 bytes) → hex (32 chars)          │
│                                          │
│ Example:                                 │
│ - ciphertext_hex: "a1b2c3d4e5f6..."     │
│ - nonce_hex: "789abc0def123456..." (24) │
│ - tag_hex: "7890abcdef123456..." (32)   │
└────────┬──────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│ STORE IN DATABASE                        │
│ Table: entries                           │
│ Columns:                                 │
│ - encrypted_secret: ciphertext_hex       │
│ - cipher_nonce: nonce_hex                │
│ - cipher_tag: tag_hex                    │
└──────────────────────────────────────────┘
```

### 6.3 Storage Layout (RAM vs DB)

```
┌─────────────────────────────────────────────────────────────┐
│ RUNTIME MEMORY (RAM) — VOLATILE, CLEARED ON EXIT           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│ Riverpod masterPasswordProvider.state                        │
│ ├─ Uint8List derivedKey (32 bytes)                         │
│ └─ Lifetime: Session only                                  │
│                                                              │
│ NEVER LOGGED, NEVER PERSISTED                              │
│                                                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ DATABASE (SQLite) — PERSISTENT, ENCRYPTED ON DEVICE        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│ Table: master_password_config (singleton, id=1)            │
│ ├─ id: 1                                                   │
│ ├─ password_hash_argon2: "abc123..." (hex, 64 chars)      │
│ │  └─ Argon2id(password, salt) — verification only       │
│ ├─ salt_hex: "def456..." (hex, 32 chars)                 │
│ │  └─ Used ONLY for KDF, NEVER for encryption            │
│ └─ created_at, updated_at                                 │
│                                                              │
│ Table: entries                                              │
│ ├─ id, topicKey, type, title, content...  [Phase 1]       │
│ ├─ secret: null (encrypted entries)                       │
│ ├─ requires_auth: true/false                              │
│ ├─ encrypted_secret: "ciphertext..." (hex) [Phase 2 NEW]  │
│ ├─ cipher_nonce: "nonce..." (hex, 24 chars) [Phase 2]     │
│ ├─ cipher_tag: "tag..." (hex, 32 chars) [Phase 2]         │
│ └─ created_at, updated_at                                 │
│                                                              │
│ NOTE: SQLite file itself is encrypted on iOS/Android      │
│ (Drift + platform-specific database encryption)            │
│                                                              │
└─────────────────────────────────────────────────────────────┘

SECURITY PRINCIPLE:
┌─────────────────────────────────────────────────────────────┐
│                                                              │
│ ✗ PLAINTEXT MASTER PASSWORD                                │
│   ├─ NEVER stored on disk                                  │
│   ├─ NEVER logged                                          │
│   └─ Only in user's head                                   │
│                                                              │
│ ✗ DERIVED MASTER KEY                                       │
│   ├─ NEVER stored on disk                                  │
│   ├─ NEVER logged                                          │
│   └─ RAM only, volatile                                    │
│                                                              │
│ ✓ MASTER PASSWORD HASH (Argon2id)                          │
│   ├─ Stored in DB (verification)                          │
│   ├─ Cannot reverse to get password                        │
│   └─ Used to verify user entry                            │
│                                                              │
│ ✓ CIPHERTEXT + NONCE + TAG                                 │
│   ├─ Stored in DB                                          │
│   ├─ Useless without derived key                          │
│   └─ Requires correct password to decrypt                 │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 6.4 Threat Model Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                       THREAT LANDSCAPE                        │
└──────────────────────────────────────────────────────────────┘

┌─ ATTACK: Unauthorized DB Access (E.g., Device Theft) ────────┐
│                                                              │
│  Attacker obtains entries.db file                           │
│                                                              │
│  ✗ Without this design:                                     │
│    └─ Plaintext secrets readable: "password123"             │
│                                                              │
│  ✓ With AES-256-GCM:                                        │
│    ├─ ciphertext: "a1b2c3d4e5..." (garbage)                │
│    ├─ nonce: "789abc0def..." (known, random)               │
│    ├─ tag: "7890abcdef..." (known, random)                 │
│    ├─ Needed to decrypt: masterKey (Uint8List)             │
│    └─ Result: Secrets PROTECTED                            │
│                                                              │
│  ✗ Attack vector: Brute force password                      │
│    ├─ Try: "password"                                      │
│    ├─ Derive key: Argon2id(password, salt)                │
│    ├─ Decrypt: AES-256-GCM(ciphertext, key, nonce)        │
│    ├─ Verify: GCM tag check                                │
│    ├─ Time per attempt: 150-250ms                          │
│    └─ Attempts per day: ~345,600 (single device)           │
│                                                              │
│  ✓ With Argon2id(t=2, m=65536, p=1):                       │
│    └─ Industry standard for password-based KDF             │
│    └─ Slow enough to deter brute force                     │
│    └─ Fast enough for legit user (< 1 second)             │
│                                                              │
└──────────────────────────────────────────────────────────────┘

┌─ ATTACK: GCM Tag Tampering ──────────────────────────────────┐
│                                                              │
│  Attacker modifies ciphertext or tag in DB                  │
│                                                              │
│  ✗ Without authentication:                                  │
│    └─ Decryption produces garbage (undetected)              │
│                                                              │
│  ✓ With AES-256-GCM:                                        │
│    ├─ GCM provides authentication tag (16 bytes)           │
│    ├─ Tag computed over ciphertext + nonce + key           │
│    ├─ On decrypt: verify tag before returning plaintext    │
│    ├─ Tag mismatch → CryptoException (atomic)              │
│    └─ Tampering detected, no data leak                     │
│                                                              │
└──────────────────────────────────────────────────────────────┘

┌─ ATTACK: Nonce Reuse ────────────────────────────────────────┐
│                                                              │
│  Attacker tricks app into reusing nonce + same key          │
│                                                              │
│  ✗ In naive GCM:                                            │
│    └─ XOR of two plaintexts leaks patterns                 │
│                                                              │
│  ✓ This design:                                             │
│    ├─ NEW nonce per encrypt (Random.secure())              │
│    ├─ 12-byte nonce = 2^96 possible values                 │
│    ├─ Collision probability: negligible                    │
│    ├─ Test: 100+ encrypts → 100+ unique nonces             │
│    └─ Nonce reuse prevented                                │
│                                                              │
└──────────────────────────────────────────────────────────────┘

┌─ ATTACK: Memory Forensics (App Running) ─────────────────────┐
│                                                              │
│  Attacker reads RAM while app is running                    │
│                                                              │
│  ✗ Without care:                                            │
│    ├─ masterKey may be readable from heap                  │
│    └─ Plaintext secrets may remain in memory               │
│                                                              │
│  ✓ This design (partial):                                   │
│    ├─ masterKey stored in Riverpod StateNotifier           │
│    ├─ Only accessible via provider (some encapsulation)    │
│    ├─ Plaintext only in RevealSecretSheet (temporary)      │
│    ├─ Sheet dismissed → plaintext cleaned (no guarantee)   │
│    └─ Limitation: Dart GC is not deterministic             │
│                                                              │
│  NOTE: Phase 2.2+ can use Uint8List.clear() + ffi wipes   │
│                                                              │
└──────────────────────────────────────────────────────────────┘

┌─ ATTACK: Wrong Password (User Mistake) ──────────────────────┐
│                                                              │
│  User enters wrong master password                          │
│                                                              │
│  ✗ Without verification:                                    │
│    └─ Decryption produces garbage (silent failure)          │
│                                                              │
│  ✓ With verification:                                       │
│    ├─ Hash check: Argon2id(userInput) vs stored hash       │
│    ├─ On mismatch: reject before attempting decrypt       │
│    ├─ Fast feedback to user: "Invalid password"            │
│    └─ Plaintext never corrupted                            │
│                                                              │
└──────────────────────────────────────────────────────────────┘

SUMMARY OF MITIGATIONS:
┌──────────────────────────────────────────────────────────────┐
│ Threat                  │ Mitigation                          │
├─────────────────────────┼─────────────────────────────────────┤
│ Plaintext leak (theft)   │ AES-256-GCM encryption             │
│ Tampering                │ GCM authentication tag (16B)        │
│ Nonce reuse              │ Random.secure() per encrypt        │
│ Brute force              │ Argon2id KDF (slow, 150-250ms)     │
│ Memory forensics         │ Volatile state, cleared on exit    │
│ Wrong password           │ Hash verification before decrypt   │
│ Plaintext in logs        │ No master password/key logged      │
└──────────────────────────────────────────────────────────────┘
```

---

## Implementation Approach

### 7.1 File Structure

```
lib/
├── src/
│   ├── domain/
│   │   ├── entities/
│   │   │   ├── entry.dart
│   │   │   ├── master_password_config.dart
│   │   │   └── encryption_result.dart
│   │   ├── exceptions/
│   │   │   └── entry_auth_exceptions.dart
│   │   └── repositories/
│   │       ├── entry_repository.dart
│   │       └── master_password_config_repository.dart
│   │
│   ├── application/
│   │   ├── providers/
│   │   │   ├── entry_auth_providers.dart      [NEW]
│   │   │   ├── master_password_providers.dart [NEW]
│   │   │   └── app_database_provider.dart     [existing]
│   │   └── use_cases/
│   │       ├── set_master_password_usecase.dart     [NEW]
│   │       ├── reveal_secret_usecase.dart           [NEW]
│   │       ├── create_protected_entry_usecase.dart  [NEW]
│   │       └── search_with_protection_usecase.dart  [NEW]
│   │
│   ├── infrastructure/
│   │   ├── services/
│   │   │   └── entry_auth_service.dart        [NEW]
│   │   └── persistence/
│   │       ├── app_database.dart              [MODIFIED]
│   │       ├── migrations/
│   │       │   ├── migration_1_initial.dart   [Phase 1]
│   │       │   └── migration_2_phase2.dart    [NEW]
│   │       └── daos/
│   │           ├── entries_dao.dart           [MODIFIED]
│   │           └── master_password_config_dao.dart [NEW]
│   │
│   └── presentation/
│       ├── screens/
│       │   └── entry_detail_screen.dart      [MODIFIED]
│       ├── widgets/
│       │   ├── entry_detail_view.dart        [MODIFIED]
│       │   ├── create_entry_form.dart        [MODIFIED]
│       │   ├── reveal_secret_sheet.dart      [NEW]
│       │   ├── master_password_setup_dialog.dart [NEW]
│       │   └── protected_entry_badge.dart    [NEW]
│       └── view_models/
│           ├── entry_detail_viewmodel.dart   [MODIFIED]
│           └── entry_auth_viewmodel.dart     [NEW]
```

### 7.2 Module Dependencies

```
Presentation Layer
├─ EntryDetailView
│  ├─ ref.watch(entriesProvider)
│  ├─ ref.watch(unlockedEntriesProvider)
│  └─ onTap: [Reveal Secret] → RevealSecretSheet
│
├─ RevealSecretSheet [NEW]
│  ├─ Input: userPassword (String)
│  ├─ ref.read(entryAuthServiceProvider)
│  ├─ ref.read(masterPasswordConfigRepositoryProvider)
│  ├─ ref.read(unlockedEntriesProvider.notifier)
│  └─ Decrypt flow (Step 3.3)
│
├─ CreateEntryForm [MODIFIED]
│  ├─ Toggle: "Protect this entry?"
│  └─ if (ON) → MasterPasswordSetupDialog or proceed
│
└─ MasterPasswordSetupDialog [NEW]
   ├─ Input: masterPassword, confirm
   ├─ ref.read(entryAuthServiceProvider)
   ├─ ref.read(masterPasswordConfigRepositoryProvider.notifier)
   ├─ ref.read(masterPasswordProvider.notifier)
   └─ Setup flow (Step 1)

Infrastructure Services
├─ EntryAuthService [NEW]
│  ├─ encrypt()
│  ├─ decrypt()
│  ├─ deriveMasterKey()
│  ├─ hashPassword()
│  └─ generateSalt()
│
├─ EntryRepository [MODIFIED]
│  ├─ create(entry) → Handle encrypted fields
│  ├─ read(id)
│  ├─ update(entry) → Re-encrypt if secret changed
│  └─ delete(id)
│
└─ MasterPasswordConfigRepository [NEW]
   ├─ get() → Singleton (or null)
   ├─ create(config)
   └─ update(config)

Persistence Layer (Drift ORM)
├─ $EntriesTable [MODIFIED with 4 new columns]
├─ $MasterPasswordConfigTable [NEW]
├─ $AppDatabase [MODIFIED with migration]
└─ SQLite driver

Riverpod Providers
├─ entryAuthServiceProvider → Singleton
├─ masterPasswordProvider → StateNotifier<Uint8List?>
├─ unlockedEntriesProvider → StateNotifier<Set<int>>
└─ entriesProvider → Stream/AsyncValue from DB
```

### 7.3 Integration Points

**Riverpod + Drift:**
```dart
// Provider depends on Drift
final entryRepositoryProvider = Provider((ref) {
  final db = ref.watch(appDatabaseProvider);
  return EntryRepository(db);
});

// Use case depends on provider + service
final revealSecretUseCaseProvider = Provider((ref) {
  final authService = ref.watch(entryAuthServiceProvider);
  final configRepo = ref.watch(masterPasswordConfigRepositoryProvider);
  final entryRepo = ref.watch(entryRepositoryProvider);
  return RevealSecretUseCase(authService, configRepo, entryRepo);
});

// Widget watches provider
class RevealSecretSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlockedProvider = ref.watch(unlockedEntriesProvider);
    final masterPasswordProvider = ref.watch(masterPasswordProvider);
    
    return Column(
      children: [
        if (masterPasswordProvider == null)
          PasswordInputField(
            onSubmit: (password) {
              // Call use case
              ref.read(revealSecretUseCaseProvider)
                .call(password, entry.id)
                .then((_) => Navigator.pop(context));
            },
          ),
      ],
    );
  }
}
```

**go_router integration (unchanged):**
```dart
GoRoute(
  path: '/entry/:id',
  builder: (context, state) {
    final entryId = int.parse(state.pathParameters['id']!);
    return EntryDetailScreen(entryId: entryId);
  },
)
```

---

## Error Handling

### 8.1 Error Handling Flowchart

```
┌────────────────────────────────────────────────────────────┐
│ USER ACTION: Click [Reveal Secret] on protected entry     │
└───────────────────────────────────────────────────────────┘
                          │
                          ▼
                ┌──────────────────────┐
                │ Show Password Input  │
                │ (RevealSecretSheet)  │
                └──────────┬───────────┘
                           │
                           ▼
                ┌──────────────────────────┐
                │ User clicks [Unlock]     │
                │ (inputPassword entered)  │
                └──────────┬───────────────┘
                           │
                ┌──────────┴──────────┐
                │                     │
                ▼                     ▼
         ┌────────────────┐  ┌────────────────┐
         │ Hash Verify    │  │ No exception   │
         │ PASS?          │  │ (all good)     │
         └────────┬───────┘  └────────┬───────┘
                  │ YES                │ NO
                  ▼                    ▼
         ┌───────────────────┐ ┌──────────────────┐
         │ Derive Key        │ │ AuthException    │
         │ (Argon2id)        │ │ "Invalid pwd"    │
         │ Duration: ~200ms  │ │                  │
         └────────┬──────────┘ │ Show error toast │
                  │            │ Stay in sheet    │
                  ▼            └──────────────────┘
         ┌───────────────────┐
         │ Decrypt Secret    │
         │ (AES-256-GCM)     │
         │ Duration: ~5ms    │
         └────────┬──────────┘
                  │
        ┌─────────┴──────────┐
        │                    │
        ▼                    ▼
   ┌─────────────┐   ┌────────────────────────┐
   │ SUCCESS     │   │ CryptoException        │
   │ Plaintext   │   │ "Decryption failed"    │
   │ returned    │   │ (GCM tag failed)       │
   └─────┬───────┘   │                        │
         │           │ Show error toast       │
         ▼           │ Stay in sheet          │
   ┌─────────────────┤ (password was wrong)   │
   │ Display secret  │                        │
   │ in sheet        │ └────────────────────────┘
   │ + Copy button   │
   │ + 30s timer     │
   └─────┬───────────┘
         │
         │ 30 seconds pass OR user dismisses
         │
         ▼
   ┌──────────────────────────────┐
   │ Auto-hide secret             │
   │ Remove from unlockedEntries  │
   │ Cancel timer                 │
   │ Sheet dismisses              │
   │ UI back to normal            │
   └──────────────────────────────┘
```

### 8.2 User-Facing Error Messages

| Error | Cause | Message | Recovery |
|-------|-------|---------|----------|
| **AuthException: Password cannot be empty** | User presses Unlock with empty field | "Please enter your password" | Retry |
| **AuthException: Invalid password** | Hash mismatch | "Wrong password. Try again." | Retry |
| **CryptoException: Decryption failed (password wrong?)** | GCM tag verification failed | "Failed to unlock (corrupted data?)" | Contact support |
| **CryptoException: Key must be 32 bytes** | Bug in key derivation | "System error: invalid key size" | Restart app |
| **CryptoException: Invalid salt hex** | Corrupted master_password_config | "System error: corrupted config" | Restart app |
| **DatabaseException** | Drift migration failure | "Database error (try restart app)" | Restart app |

### 8.3 Logging Strategy

**NEVER LOG:**
```dart
// ❌ DON'T DO THIS
logger.info('Master password: $password'); // LEAK!
logger.debug('Derived key: $derivedKey');   // LEAK!
logger.error('Plaintext: $secret');         // LEAK!
```

**SAFE LOGGING:**
```dart
// ✅ DO THIS
logger.info('Master password setup initiated');
logger.debug('Derived key from password (not logged)');
logger.info('Entry decrypted successfully');
logger.error('GCM tag verification failed (no details)');

// Include non-sensitive context
logger.info('Setup flow', extra: {
  'step': 'password_setup',
  'entropy_source': 'Random.secure()',
  'salt_length': 16,
  // NO password, NO key
});
```

---

## Database Migration Strategy

### 9.1 Schema Diagrams

**Phase 1 Schema (v1):**
```
┌─ entries table ──────────────────────┐
│                                      │
│ Column         │ Type               │
├────────────────┼────────────────────┤
│ id (PK)        │ INTEGER PRIMARY    │
│ topic_key (FK) │ TEXT NOT NULL      │
│ type           │ TEXT NOT NULL      │
│ title          │ TEXT NOT NULL      │
│ secret         │ TEXT NOT NULL      │ ← Plaintext
│ content        │ TEXT NOT NULL      │
│ created_at     │ INTEGER NOT NULL   │
│ updated_at     │ INTEGER NOT NULL   │
│                                      │
│ Indexes:                             │
│ - fts5_entries (FTS virtual table)  │
│ - idx_topic_key                      │
│ - UNIQUE(topic_key, type, title)    │
│                                      │
└──────────────────────────────────────┘

┌─ No master_password_config table ─┐
│ (Phase 1: No encryption)          │
└───────────────────────────────────┘
```

**Phase 2 Schema (v2):**
```
┌─ entries table ────────────────────────────┐
│                                            │
│ Column              │ Type                │
├─────────────────────┼────────────────────┤
│ id (PK)             │ INTEGER PRIMARY    │
│ topic_key (FK)      │ TEXT NOT NULL      │
│ type                │ TEXT NOT NULL      │
│ title               │ TEXT NOT NULL      │
│ secret              │ TEXT NULL          │ ← NOW NULLABLE
│ content             │ TEXT NOT NULL      │
│ created_at          │ INTEGER NOT NULL   │
│ updated_at          │ INTEGER NOT NULL   │
├─ [PHASE 2 NEW] ────────────────────────┤
│ requires_auth       │ BOOLEAN DEFAULT 0  │
│ encrypted_secret    │ TEXT NULL          │ ← Ciphertext
│ cipher_nonce        │ TEXT NULL          │ ← 12B hex
│ cipher_tag          │ TEXT NULL          │ ← 16B hex
│                                            │
│ Indexes:                                   │
│ - fts5_entries (FTS, includes encrypted)  │
│ - idx_topic_key                            │
│ - idx_requires_auth (for queries)          │
│ - UNIQUE(topic_key, type, title)          │
│                                            │
└────────────────────────────────────────────┘

┌─ master_password_config table [NEW] ─┐
│                                       │
│ Column              │ Type            │
├─────────────────────┼─────────────────┤
│ id (PK)             │ INTEGER PRIMARY │
│ password_hash_...   │ TEXT NOT NULL   │
│ salt_hex            │ TEXT NOT NULL   │
│ created_at          │ INTEGER NOT NULL│
│ updated_at          │ INTEGER NOT NULL│
│                                       │
│ Constraints:                          │
│ - 0 or 1 row (app enforces)          │
│                                       │
└───────────────────────────────────────┘
```

### 9.2 Migration Steps (Drift Syntax)

**File:** `lib/src/infrastructure/persistence/migrations/migration_2_phase2.dart`

```dart
import 'package:drift/drift.dart';

// Migration definition
const migration_2_phase2 = '''
-- Add new columns to entries table
ALTER TABLE entries ADD COLUMN requires_auth BOOLEAN DEFAULT 0;
ALTER TABLE entries ADD COLUMN encrypted_secret TEXT;
ALTER TABLE entries ADD COLUMN cipher_nonce TEXT;
ALTER TABLE entries ADD COLUMN cipher_tag TEXT;

-- Create master_password_config table
CREATE TABLE master_password_config (
  id INTEGER PRIMARY KEY,
  password_hash_argon2 TEXT NOT NULL,
  salt_hex TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Add index on requires_auth for faster queries
CREATE INDEX idx_entries_requires_auth ON entries(requires_auth);

-- Update FTS5 table to include encrypted_secret (optional, FTS handles dynamically)
-- FTS5 will automatically index new columns on next query
''';

// Drift migration class
@DataClassName('Migration_2_Phase2')
class Migration_2_Phase2 extends Migration {
  @override
  int get schemaVersion => 2;

  @override
  Future<void> onUpgrade(Migrator m, int from, int to) async {
    if (from == 1 && to == 2) {
      // Add columns (nullable by default)
      await m.addColumn(entries, entries.requiresAuth);
      await m.addColumn(entries, entries.encryptedSecret);
      await m.addColumn(entries, entries.cipherNonce);
      await m.addColumn(entries, entries.cipherTag);

      // Create new table
      await m.create(masterPasswordConfig);

      // Create index
      await m.createIndex(Index(
        'idx_entries_requires_auth',
        on: entries.requiresAuth,
      ));
    }
  }
}
```

### 9.3 Backward Compatibility Notes

| Aspect | Phase 1 | Phase 2 | Compatibility |
|--------|---------|---------|---|
| **Old entry (plaintext)** | `secret = 'password123'`<br/>`requiresAuth = null` | `secret = 'password123'`<br/>`requiresAuth = false` | ✅ Fully compatible |
| **New protected entry** | N/A | `secret = null`<br/>`requiresAuth = true`<br/>`encryptedSecret = 'abc...'` | ✅ Handles migration |
| **FTS5 search** | `secret MATCH query` | `secret MATCH query OR encryptedSecret MATCH query` | ✅ Enhanced search |
| **App downgrade** | N/A | App reads Phase 2 cols (nullable) | ⚠️ Not recommended |
| **DB backup** | Plaintext backup | Ciphertext backup (Phase 2 entries) | ✅ Safe to backup |

**Migration Safety Checklist:**
- ✅ All new columns are NULLABLE (Phase 1 rows not affected)
- ✅ Default values: `requiresAuth = false`, others NULL (backward-safe)
- ✅ No data loss (Phase 1 data preserved as-is)
- ✅ FTS5 handles new column automatically
- ✅ Indexes created for performance (requires_auth queries fast)

---

## Performance Considerations

### 10.1 Timing Profile

| Operation | Duration | Notes |
|-----------|----------|-------|
| **Argon2id(password, salt)** | 150-250ms | Key derivation + hash (async) |
| **AES-256-GCM encrypt** | 2-5ms (100B)<br/>20-50ms (1MB) | Parallelizable, non-blocking |
| **AES-256-GCM decrypt** | 2-10ms (100B)<br/>20-50ms (1MB) | Includes GCM tag verification |
| **FTS5 search (100 entries)** | < 200ms | Unaffected by encryption (Phase 1 data fast) |
| **FTS5 search (10 protected entries)** | < 200ms | Encrypted secrets indexed normally |
| **Entry save to DB** | < 50ms | Single INSERT + index updates |
| **Master password setup** | 200-350ms | Argon2id + generateSalt |
| **Reveal secret (first time)** | 200-250ms | Argon2id verify + decrypt |
| **Reveal secret (session cached)** | 0ms | State lookup only |

### 10.2 Caching Strategy

```
┌──────────────────────────────────────────────────────────┐
│ masterPasswordProvider (Riverpod StateNotifier)          │
│                                                          │
│ State: Uint8List? derivedKey                            │
│ ├─ NULL: No master password in memory                  │
│ └─ Uint8List(32B): Master key ready to decrypt         │
│                                                          │
│ WHEN POPULATED:                                          │
│ ├─ After user enters correct password (Step 3.5)       │
│ ├─ Derived via Argon2id (one-time, 200ms)             │
│ └─ Reused for ALL decrypts in session                  │
│                                                          │
│ LIFETIME:                                                │
│ ├─ Stored in RAM (volatile)                            │
│ ├─ Cleared on: App exit, Manual logout, Dispose        │
│ └─ Duration: Entire app session                        │
│                                                          │
│ BENEFIT:                                                 │
│ ├─ Subsequent reveals: INSTANT (cache hit)             │
│ ├─ Avg flow: First reveal 250ms, next reveals 5ms     │
│ └─ No re-derivation needed                             │
│                                                          │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ unlockedEntriesProvider (Riverpod StateNotifier)         │
│                                                          │
│ State: Set<int> unlockedIds                             │
│ ├─ {}: All entries locked (default)                    │
│ └─ {123, 456}: Entries 123, 456 unlocked               │
│                                                          │
│ WHEN UPDATED:                                            │
│ ├─ After successful decrypt (Step 3.8)                 │
│ ├─ Entry ID added to set                               │
│ ├─ 30-second timer started                             │
│ └─ UI shows plaintext (no [Reveal] button)             │
│                                                          │
│ AUTO-CLEAR:                                              │
│ ├─ After 30 seconds: removeUnlockedEntry()             │
│ ├─ OR manual dismiss: UI callback                       │
│ └─ OR app termination: clearAll()                       │
│                                                          │
│ BENEFIT:                                                 │
│ ├─ User can view secret without re-entering password   │
│ ├─ Auto-hide prevents accidental exposure               │
│ └─ Independent timers per entry (concurrent)           │
│                                                          │
└──────────────────────────────────────────────────────────┘

CACHING TRADE-OFFS:

✓ ADVANTAGE: Faster UX
  ├─ First unlock: 250ms (Argon2id + decrypt)
  └─ Next unlocks: 5ms (cache hit)

✓ ADVANTAGE: Reduced battery drain
  ├─ No re-hashing in session
  └─ Fewer crypto operations

✗ RISK: Memory exposure
  ├─ derivedKey in RAM (mitigated by volatile)
  └─ Unlocked entry cache (30s timeout)

✓ MITIGATION: Timeout-based invalidation
  ├─ 30s per entry (UI auto-hides)
  └─ User controls reveal behavior

ALTERNATIVE (if extreme paranoia):
  └─ No caching: Argon2id on EVERY reveal (very slow)
```

### 10.3 Optimization Guidelines

**DO:**
- ✅ Cache derivedKey in Riverpod (first Argon2id → all decrypts)
- ✅ Use async/await for Argon2id (don't block UI)
- ✅ Batch multiple entries.update() to single DB transaction
- ✅ Use FTS5 indexes (already in Phase 1)
- ✅ Pre-compute encrypted_secret during entry save (not on read)

**DON'T:**
- ❌ Re-derive key for every decrypt (kills UX)
- ❌ Encrypt in main thread (UI freeze)
- ❌ Store plaintext in logs (security risk)
- ❌ Cache masterPassword string (only cache derivedKey)
- ❌ Use default Random (not Random.secure() for nonce)

---

## Testing Architecture

### 11.1 Test Pyramid

```
                  /\
                 /  \         E2E Tests (2-3)
                /____\        └─ Full user journey
               /      \
              /  ▲▲▲   \      Integration Tests (8-10)
             / ▲ ▲ ▲ ▲  \    └─ Encrypt → Store → Decrypt
            /▲ ▲ ▲ ▲ ▲ ▲ \
           /___▲_▲_▲_▲_▲_▲_\  Unit Tests (30-35)
                              └─ Service, Provider, Widget
```

### 11.2 Test Coverage by Layer

| Layer | Coverage | Example Tests |
|-------|----------|---|
| **Unit: EntryAuthService** | 90%+ | encrypt_roundtrip, decrypt_wrong_password, nonce_uniqueness (100+ encrypts) |
| **Unit: Riverpod Providers** | 85%+ | masterPasswordProvider state transitions, unlockedEntriesProvider timer |
| **Integration: DB + Encryption** | 80%+ | Create protected entry → save → read → decrypt |
| **Widget: UI Components** | 75%+ | RevealSecretSheet password input, CreateEntryForm toggle |
| **E2E: Full Flow** | ~Full journey | User creates protected entry → searches → unlocks → views |
| **Overall Target** | ≥80% | Emphasis on critical path (encrypt/decrypt) |

### 11.3 Test Scenarios

**Unit Test: Encryption Roundtrip**
```dart
test('encrypt_decrypt_roundtrip_with_unicode', () async {
  final service = EntryAuthService();
  const plaintext = 'Contraseña123!🔒';
  final key = Uint8List(32); // all zeros (for testing)

  // Encrypt
  final encrypted = service.encrypt(plaintext, key);

  // Verify encrypted != plaintext
  expect(encrypted.encryptedSecret, isNotEmpty);
  expect(encrypted.nonce, isNotEmpty);
  expect(encrypted.tag, isNotEmpty);

  // Decrypt
  final decrypted = await service.decrypt(
    encrypted.encryptedSecret,
    encrypted.nonce,
    encrypted.tag,
    key,
  );

  // Verify roundtrip
  expect(decrypted, equals(plaintext));
});
```

**Unit Test: Nonce Uniqueness**
```dart
test('100_encrypts_produce_unique_nonces', () async {
  final service = EntryAuthService();
  const plaintext = 'Secret';
  final key = Uint8List(32);
  final nonces = <String>{};

  for (int i = 0; i < 100; i++) {
    final result = service.encrypt(plaintext, key);
    nonces.add(result.nonce);
  }

  expect(nonces.length, equals(100)); // All unique
});
```

**Widget Test: RevealSecretSheet**
```dart
testWidgets('reveal_secret_sheet_shows_password_input', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RevealSecretSheet(entry: mockEntry),
      ),
    ),
  );

  // Find password field
  expect(find.byType(TextField), findsOneWidget);

  // Enter password
  await tester.enterText(find.byType(TextField), 'correctPassword');
  await tester.tap(find.text('Unlock'));
  await tester.pumpAndSettle();

  // Verify plaintext shown
  expect(find.text('MySecretPassword123!'), findsOneWidget);
});
```

**Integration Test: Create Protected Entry**
```dart
test('create_protected_entry_flow', () async {
  // Setup
  final db = await inMemoryDatabase();
  final authService = EntryAuthService();
  final masterPasswordConfigRepo = MasterPasswordConfigRepository(db);
  
  // 1. Setup master password (first time)
  final salt = authService.generateSalt();
  final derivedKey = await authService.deriveMasterKey('password123', salt);
  final passwordHash = await authService.hashPassword('password123', salt);
  
  await masterPasswordConfigRepo.create(
    MasterPasswordConfig(
      id: 1,
      passwordHashArgon2: passwordHash,
      saltHex: salt,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  );

  // 2. Create protected entry
  final plaintext = 'SecretPassword456';
  final encrypted = authService.encrypt(plaintext, derivedKey);

  final entry = Entry(
    id: 1,
    topicKey: 'credentials',
    type: 'password',
    title: 'GitHub',
    secret: null,
    content: 'github.com',
    requiresAuth: true,
    encryptedSecret: encrypted.encryptedSecret,
    cipherNonce: encrypted.nonce,
    cipherTag: encrypted.tag,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final entryRepo = EntryRepository(db);
  await entryRepo.create(entry);

  // 3. Verify saved
  final saved = await entryRepo.read(1);
  expect(saved?.requiresAuth, isTrue);
  expect(saved?.encryptedSecret, isNotNull);

  // 4. Decrypt and verify roundtrip
  final decrypted = await authService.decrypt(
    saved!.encryptedSecret!,
    saved.cipherNonce!,
    saved.cipherTag!,
    derivedKey,
  );
  expect(decrypted, equals(plaintext));
});
```

---

## Architectural Decision Records

### ADR-001: Per-Entry vs Global Vault

**Status:** ACCEPTED (Phase 2 Design)

**Context:** User needs to protect credenciales without global authentication friction.

**Decision:** Implement per-entry protection with selective `requiresAuth` flag.

**Rationale:**
- ✅ Users can search/browse unprotected entries normally
- ✅ Only authenticate when revealing sensitive secrets
- ✅ Simpler than managing session timeout globally
- ✅ Clear separation: Some data protected, some public

**Rejected Alternatives:**
- ❌ Global vault with session timeout: Too much friction ("Why ask for password to search notes?")
- ❌ All-or-nothing encryption: Forces users to protect everything or nothing

**Consequences:**
- ✓ Better UX (zero friction on search)
- ✗ More complex schema (4 new columns per entry)
- ✗ Must manage multiple unlock timers independently

---

### ADR-002: AES-256-GCM + Argon2id

**Status:** ACCEPTED (Phase 2 Design)

**Context:** Need to encrypt secrets with modern, NIST-approved algorithms.

**Decision:** Use AES-256-GCM for encryption + Argon2id for KDF.

**Rationale:**
- ✅ AES-256-GCM is NIST standard, AEAD (authenticated encryption)
- ✅ GCM tag detects tampering automatically
- ✅ Argon2id is winner of Password Hashing Competition (PHC)
- ✅ Argon2id resistant to both GPU and ASIC brute force
- ✅ t=2, m=65536, p=1 balances speed (150-250ms) and security

**Rejected Alternatives:**
- ❌ AES-128-GCM: Smaller key space, less future-proof
- ❌ ChaCha20-Poly1305: Good, but AES-256 more widely audited
- ❌ PBKDF2: Weaker than Argon2id (GPU-optimized attacks)
- ❌ bcrypt: Good, but Argon2id newer + parallelism-resistant

**Consequences:**
- ✓ Strong cryptography, expert consensus
- ✓ Transparent to users (no UX impact)
- ✗ Argon2id slower (150-250ms derivation time)
  - Mitigated: Cache derivedKey in Riverpod (only once per session)

---

### ADR-003: Volatile Riverpod State vs Secure Storage

**Status:** ACCEPTED (Phase 2 Design)

**Context:** Where to store derived master key during app session?

**Decision:** Store in Riverpod StateNotifier (volatile, RAM), NOT in flutter_secure_storage (persistent).

**Rationale:**
- ✅ Master PASSWORD never stored (only in user's head)
- ✅ Derived KEY is volatile (cleared on app exit)
- ✅ Riverpod state is easy to manage + clear
- ✅ No persistent storage = no reverse-engineering risk
- ✅ Lower complexity (no platform-specific secure storage)

**Rejected Alternatives:**
- ❌ flutter_secure_storage: Master key would persist on disk (security risk)
- ❌ HiveBox + encryption: Adds complexity, false sense of security
- ❌ File-based encryption: Risk of key recovery post-exit

**Consequences:**
- ✓ Simpler architecture
- ✓ Better security (key never on disk)
- ✗ User must re-enter password after app restart
  - Acceptable: First unlock cached for session

---

### ADR-004: 30-Second Unlock Timeout

**Status:** ACCEPTED (Phase 2 Design)

**Context:** How long should revealed secrets remain visible?

**Decision:** 30-second auto-hide timeout per entry.

**Rationale:**
- ✅ Enough time for user to copy-paste secret
- ✅ Short enough to reduce accidental exposure risk
- ✅ Familiar pattern (e.g., password managers)
- ✅ Independent per entry (don't force all revert)

**Rejected Alternatives:**
- ❌ Infinite (user manual dismiss only): Accidental exposure risk
- ❌ 5 seconds: Too short (user can't copy comfortably)
- ❌ 60+ seconds: Too long (exposure window)
- ❌ Global timeout (all entries revert together): Less UX-friendly

**Consequences:**
- ✓ Good balance of security + usability
- ✓ Can adjust in Phase 2.1 based on feedback
- ✗ Timer management adds complexity (Riverpod notifier)

---

### ADR-005: No Biometrics Phase 2

**Status:** ACCEPTED (Phase 2 Design)

**Context:** Should we add fingerprint/face unlock in Phase 2?

**Decision:** OUT OF SCOPE for Phase 2. Password-only, biometrics in Phase 2.1+.

**Rationale:**
- ✅ Reduces scope (20 hours → 20 hours, not 30+)
- ✅ Password-only simpler to implement + test
- ✅ Biometrics adds platform-specific complexity (iOS/Android)
- ✅ Foundation (Argon2id + AES-256-GCM) supports biometrics later

**Rejected Alternatives:**
- ❌ Include biometrics Phase 2: Scope creep, risk
- ❌ Skip forever: Biometrics valuable for UX

**Future Work:**
- Phase 2.1: Add local_auth package + biometric unlock (parallel to password)

**Consequences:**
- ✓ On-time delivery (20 hours, LOW risk)
- ✓ Foundation ready for biometrics (just extend RevealSecretSheet)
- ✗ Users must type password on every entry (acceptable for Phase 2)

---

### ADR-006: FTS5 Search Includes Encrypted Secrets

**Status:** ACCEPTED (Phase 2 Design)

**Context:** Should FTS5 search encrypted secrets?

**Decision:** YES. FTS5 searches encrypted_secret column too (but results show plaintext only if unlocked).

**Rationale:**
- ✅ Users can find protected entries by searching
- ✅ Encrypted text in FTS index is safe (garbage to attacker)
- ✅ No performance impact (FTS5 handles dynamic columns)
- ✅ Feature complete: "Find my protected password for 'GitHub'"

**Rejected Alternatives:**
- ❌ Don't index encrypted_secret: Users can't find protected entries
- ❌ Decrypt all secrets on search: Performance + security risk

**Consequences:**
- ✓ Better discoverability
- ✓ Minimal perf impact (< 200ms search)
- ✗ Encrypted data still visible in FTS virtual table (low risk, mitigated by FTS encryption)

---

### ADR-007: Nullable `secret` Column (Phase 1 Compatibility)

**Status:** ACCEPTED (Phase 2 Design)

**Context:** Phase 1 has `secret NOT NULL`. Should Phase 2 make it nullable?

**Decision:** YES. Make `secret` nullable in Phase 2 to distinguish plaintext vs encrypted.

**Rationale:**
- ✅ Invariant: `(requiresAuth=true AND secret=null AND encryptedSecret!=null)` OR `(requiresAuth=false AND secret!=null AND encryptedSecret=null)`
- ✅ Backward compatible: Phase 1 entries `secret!=null` with `requiresAuth=false`
- ✅ Clear state machine (encrypted entries have NULL secret)
- ✅ Prevents accidental leaks (checking != null catches bugs)

**Rejected Alternatives:**
- ❌ Keep `secret NOT NULL`, use empty string for encrypted: Ambiguous, error-prone
- ❌ Always store both secret + encryptedSecret: Redundant, confusing

**Consequences:**
- ✓ Clearer state (NULL = encrypted)
- ✓ Backward compatible with Phase 1
- ✗ Must handle NULL in queries/display
- ✗ Migration adds `DEFAULT NULL` to Phase 1 rows

---

## Summary & Readiness

### Phase 2 Design Complete ✅

| Component | Status | Notes |
|-----------|--------|-------|
| **Architecture (7-layer)** | ✅ Complete | Riverpod + Drift + Services |
| **EntryAuthService** | ✅ Specified | All methods, exceptions, performance |
| **Riverpod Providers** | ✅ Designed | masterPasswordProvider + unlockedEntriesProvider |
| **Data Models** | ✅ Defined | Entry + MasterPasswordConfig + EncryptionResult |
| **Data Flows** | ✅ Documented | Setup (8 steps), Create (6 steps), Reveal (9 steps), Search (5 steps) |
| **Security** | ✅ Analyzed | Threat model, key derivation, encryption flow |
| **Database** | ✅ Migration | v1→v2 schema, Drift syntax, backward compatible |
| **Error Handling** | ✅ Flowchart | User-facing messages, logging strategy |
| **Testing** | ✅ Strategy | Unit + Integration + Widget + E2E coverage |
| **ADRs** | ✅ Documented | 7 key decisions with rationale + alternatives |

### Next Phase: SDD-TASKS

Ready to break design into implementation tasks:

1. **Setup Services** (2h)
   - Implement EntryAuthService
   - Wire Riverpod providers

2. **Database Migration** (2h)
   - Drift schema + migration_2_phase2
   - Test backward compatibility

3. **UI Screens** (8h)
   - RevealSecretSheet
   - MasterPasswordSetupDialog
   - Protect toggle in CreateEntryForm
   - Protected entry badge

4. **Integration** (4h)
   - EntryDetailView → RevealSecretSheet flow
   - State management wiring
   - Search + FTS5 integration

5. **Testing** (4h)
   - Unit tests (EntryAuthService)
   - Integration tests (DB + Encryption)
   - Widget tests (UI)

**Effort:** 20 hours (1 week, 1 person)  
**Risk:** 🟢 LOW  
**Status:** Ready for SDD-TASKS phase

---

**Document Version:** 2.0-Phase2-Design  
**Last Updated:** 2025  
**Approval:** Ready for Implementation  
