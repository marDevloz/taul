# Diagramas de Arquitectura — Fase 2 (v2): Protección Opcional de Entradas

**Taúl Phase 2 Architecture Diagrams (Simplified)**

---

## Diagrama 1: System Context

```
┌──────────────────────────────────────────────────────────────┐
│                       Taúl User                              │
│                    (Flutter App)                             │
└──────────────┬─────────────────────────────────────┬─────────┘
               │                                     │
               │                                     │
     ┌─────────▼──────────┐                ┌────────▼────────┐
     │  EntryDetailView   │                │  CreateEntry    │
     │  (+ RevealSheet)   │                │    Form         │
     └─────────┬──────────┘                └────────┬────────┘
               │                                    │
               └────────────────┬───────────────────┘
                                │
                    ┌───────────▼────────────┐
                    │  EntryAuthService      │
                    │  (AES-256-GCM encrypt/ │
                    │   Argon2id derive)     │
                    └───────────┬────────────┘
                                │
                ┌───────────────┴───────────────┐
                │                               │
     ┌──────────▼────────────┐      ┌──────────▼─────────┐
     │  SQLite (Drift)       │      │  Riverpod State    │
     │  - entries (+ cols)   │      │  - masterPassword  │
     │  - master_password... │      │  - unlockedEntries │
     │    config             │      └────────────────────┘
     └───────────────────────┘
```

---

## Diagrama 2: Data Flow - Create Protected Entry

```
┌─────────────────────────────────────────────────────────────┐
│ User: Create Entry with "Protect" toggle ON                │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
        ┌─────────────────────┐
        │ Is First Protection?│
        └─────────────────────┘
                  │
        ┌─────────┴─────────┐
        │                   │
       YES                 NO
        │                   │
        ▼                   ▼
  ┌──────────────────┐   ┌──────────────────┐
  │ MasterPassword   │   │ Use existing salt│
  │ Setup Dialog     │   │ from config      │
  │ (Set password)   │   └──────────────────┘
  └────────┬─────────┘             │
           │                       │
           ▼                       │
  ┌──────────────────────┐        │
  │ generateSalt()       │        │
  │ → salt (16 bytes)    │        │
  └────────┬─────────────┘        │
           │                      │
           └──────────┬───────────┘
                      │
                      ▼
           ┌─────────────────────┐
           │ Argon2id(password,  │
           │ salt, t=2, m=65536) │
           │ → derivedKey (32B)  │
           └────────┬────────────┘
                    │
                    ▼
       ┌────────────────────────┐
       │ Store in riverpod:     │
       │ masterPasswordProvider │
       │ = derivedKey           │
       └────────┬───────────────┘
                │
                ▼
    ┌───────────────────────────┐
    │ AES-256-GCM encrypt:      │
    │ - Input: plaintext secret │
    │ - Key: derivedKey         │
    │ - Nonce: random 12 bytes  │
    │ - Output: {cipher, tag}   │
    └────────┬──────────────────┘
             │
             ▼
  ┌────────────────────────────┐
  │ Save Entry to SQLite:      │
  │ - requires_auth: true      │
  │ - encrypted_secret: cipher │
  │ - cipher_nonce: nonce      │
  │ - cipher_tag: tag          │
  └────────┬───────────────────┘
           │
           ▼
  ┌──────────────────────────┐
  │ Insert master_password   │
  │ _config (first time):    │
  │ - password_hash_argon2   │
  │ - salt_hex               │
  └────────┬─────────────────┘
           │
           ▼
  ┌──────────────────┐
  │ ✅ Entry created │
  │    & encrypted   │
  └──────────────────┘
```

---

## Diagrama 3: Data Flow - View Protected Entry

```
┌────────────────────────────────────┐
│ User: Click Protected Entry        │
└────────────┬──────────────────────┘
             │
             ▼
  ┌─────────────────────────┐
  │ EntryDetailView         │
  │ Check: requires_auth?   │
  └────────┬────────────────┘
           │
    ┌──────┴──────┐
    │             │
   NO            YES
    │             │
    │         ┌───▼──────────────────┐
    │         │ Show [🔒 Reveal]     │
    │         │ button               │
    │         └───┬──────────────────┘
    │             │
    │             ▼
    │    ┌──────────────────┐
    │    │ User clicks      │
    │    │ [Reveal Secret]  │
    │    └────┬─────────────┘
    │         │
    │         ▼
    │   ┌────────────────────┐
    │   │ RevealSecretSheet  │
    │   │ (bottom modal)     │
    │   │ - Password input   │
    │   │ - [Unlock] button  │
    │   └────┬───────────────┘
    │        │
    │        ▼
    │   ┌────────────────────────┐
    │   │ Verify Password:       │
    │   │ - Load salt from       │
    │   │   master_password_..   │
    │   │ - Argon2id(input_pwd,  │
    │   │   salt)                │
    │   │ - Compare with stored  │
    │   │   hash                 │
    │   └────┬───────────────────┘
    │        │
    │   ┌────┴────┐
    │   │          │
    │   │        MATCH
    │   │          │
    │   │    ┌─────▼──────────┐
    │   │    │ Store derivedKey
    │   │    │ in riverpod:   │
    │   │    │ masterPassword │
    │   │    │ Provider       │
    │   │    └─────┬──────────┘
    │   │          │
    │   │          ▼
    │   │  ┌──────────────────┐
    │   │  │ AES-256-GCM      │
    │   │  │ decrypt:         │
    │   │  │ - cipher text    │
    │   │  │ - nonce          │
    │   │  │ - tag            │
    │   │  │ - derivedKey     │
    │   │  │ → plaintext      │
    │   │  └─────┬────────────┘
    │   │        │
    │   │        ▼
    │   │  ┌──────────────────┐
    │   │  │ Show plaintext   │
    │   │  │ in UI            │
    │   │  └─────┬────────────┘
    │   │        │
    │   │        ▼
    │   │  ┌──────────────────┐
    │   │  │ markUnlocked()   │
    │   │  │ in riverpod      │
    │   │  │ (for 30s)        │
    │   │  └─────┬────────────┘
    │   │        │
    │   │        ▼
    │   │  ┌──────────────────┐
    │   │  │ After 30s:       │
    │   │  │ auto-hide secret │
    │   │  │ & clear          │
    │   │  └──────────────────┘
    │   │
    │   └──→ [SHOW PLAINTEXT]
    │
    └──→ [SHOW CONTENT NORMALLY]

Legend:
  MATCH = hash verification successful
  (NO MATCH → error, retry password)
```

---

## Diagrama 4: Dependency Injection (Riverpod Providers)

```
┌────────────────────────────────────────────────────────┐
│           Riverpod Provider Layer                      │
└────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ 1. entryAuthServiceProvider                            │
│    └─ Singleton: EntryAuthService instance             │
│       ├─ encrypt(plaintext, key) → {cipher, nonce, tag}│
│       ├─ decrypt(cipher, nonce, tag, key) → plaintext  │
│       ├─ deriveMasterKey(pwd, salt) → Uint8List        │
│       ├─ generateSalt() → String (hex)                 │
│       └─ hashPassword(pwd, salt) → String (hex)        │
└────────┬──────────────────────────────────────────────┘
         │ (used by)
         │
┌────────▼────────────────────────────────────────────┐
│ 2. masterPasswordProvider (StateNotifier)           │
│    State: Uint8List? (derivedKey in RAM, volatile) │
│    Methods:                                         │
│    ├─ setMasterPassword(pwd) → derive & store      │
│    ├─ clearMasterPassword() → state = null         │
│    └─ isMasterPasswordSet() → state != null?       │
└────────┬──────────────────────────────────────────┘
         │ (watched by)
         │
    ┌────┴────┬────────┬─────────┐
    │          │        │         │
    ▼          ▼        ▼         ▼
┌───────┐  ┌──────┐  ┌──────┐  ┌──────────┐
│ Entry │  │Create│  │Reveal│  │ Unlock   │
│Detail │  │Entry │  │Secret│  │ Dialog   │
│View   │  │Form  │  │Sheet │  └──────────┘
└───────┘  └──────┘  └──────┘

┌─────────────────────────────────────────────────────┐
│ 3. unlockedEntriesProvider (StateNotifier)          │
│    State: Set<String> (entry IDs unlocked this     │
│    session)                                         │
│    Methods:                                         │
│    ├─ markUnlocked(entryId) → add to set           │
│    └─ Auto-remove after 30s per entry              │
└────────┬────────────────────────────────────────────┘
         │ (watched by)
         │
    ┌────┴────┐
    │          │
    ▼          ▼
┌───────┐  ┌──────────┐
│ Entry │  │ Search   │
│Detail │  │Results   │
│ View  │  │(for 🔒)  │
└───────┘  └──────────┘

Key Points:
✅ masterPasswordProvider holds derived key (volatile)
✅ No persistence of key (cleared on app exit)
✅ entryAuthServiceProvider does encryption/decryption
✅ unlockedEntriesProvider tracks UI state only
```

---

## Diagrama 5: Database Schema (v1 → v2)

```
┌──────────────────────────────────────────────────────────┐
│ SQLite Schema Migration (Drift)                          │
└──────────────────────────────────────────────────────────┘

BEFORE (v1):
┌─────────────────────────┐
│ entries                 │
├─────────────────────────┤
│ id (PRIMARY KEY)        │
│ topic_key (TEXT)        │
│ type (TEXT) - note...   │
│ title (TEXT)            │
│ secret (TEXT) *plain*   │
│ content (TEXT)          │
│ created_at (INTEGER)    │
│ updated_at (INTEGER)    │
│ ... other fields        │
└─────────────────────────┘

AFTER (v2):
┌──────────────────────────────────────┐
│ entries                              │
├──────────────────────────────────────┤
│ id (PRIMARY KEY)                     │
│ topic_key (TEXT)                     │
│ type (TEXT)                          │
│ title (TEXT)                         │
│ secret (TEXT) [NULLABLE if encrypted]
│ content (TEXT)                       │
│ created_at (INTEGER)                 │
│ updated_at (INTEGER)                 │
│ ... other fields                     │
│                                      │
│ [NEW] requires_auth (BOOL) DEFAULT 0 │
│ [NEW] encrypted_secret (TEXT)        │
│ [NEW] cipher_nonce (TEXT)            │
│ [NEW] cipher_tag (TEXT)              │
└──────────────────────────────────────┘

NEW TABLE:
┌──────────────────────────┐
│ master_password_config   │
├──────────────────────────┤
│ id (PRIMARY KEY)         │
│ password_hash_argon2     │
│ (TEXT)                   │
│ salt_hex (TEXT)          │
│ created_at (INTEGER)     │
│ updated_at (INTEGER)     │
└──────────────────────────┘
(0 or 1 row only)

Drift Migration SQL:
────────────────────────────────────────
CREATE TABLE master_password_config (
  id INTEGER PRIMARY KEY,
  password_hash_argon2 TEXT NOT NULL,
  salt_hex TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

ALTER TABLE entries 
ADD COLUMN requires_auth BOOLEAN DEFAULT 0;

ALTER TABLE entries 
ADD COLUMN encrypted_secret TEXT;

ALTER TABLE entries 
ADD COLUMN cipher_nonce TEXT;

ALTER TABLE entries 
ADD COLUMN cipher_tag TEXT;
────────────────────────────────────────

Data Integrity:
✅ No data loss (all new columns nullable or have defaults)
✅ Backward compatible (old entries still work)
✅ No migration of existing data needed
✅ Encryption only on user action
```

---

## Diagrama 6: EntryAuthService Internals

```
┌──────────────────────────────────────────────────────┐
│ EntryAuthService (Core Cryptography)                │
└──────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────┐
│ Method: encrypt(plaintext: String,                │
│                 derivedKey: Uint8List)            │
├────────────────────────────────────────────────────┤
│                                                    │
│ 1. Generate nonce (12 bytes random)               │
│    nonce = Random.secure().nextBytes(12)          │
│                                                    │
│ 2. Create AES-256-GCM cipher                       │
│    cipher = AES(derivedKey, mode: GCMMode)        │
│                                                    │
│ 3. Encrypt plaintext                               │
│    result = cipher.encrypt(                        │
│      utf8.encode(plaintext),                       │
│      iv: nonce                                     │
│    )                                               │
│    result.bytes = ciphertext + tag (16 bytes)     │
│                                                    │
│ 4. Extract tag (last 16 bytes)                     │
│    ciphertext = result.bytes[:-16]                │
│    tag = result.bytes[-16:]                        │
│                                                    │
│ 5. Return hex-encoded result                       │
│    {                                               │
│      encryptedSecret: hex(ciphertext),             │
│      nonce: hex(nonce),                            │
│      tag: hex(tag)                                 │
│    }                                               │
└────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────┐
│ Method: decrypt(encryptedSecret: String,          │
│                 nonce: String,                     │
│                 tag: String,                       │
│                 derivedKey: Uint8List)            │
├────────────────────────────────────────────────────┤
│                                                    │
│ 1. Decode hex-encoded inputs                       │
│    ciphertext = hex.decode(encryptedSecret)       │
│    iv = hex.decode(nonce)                          │
│    tag = hex.decode(tag)                           │
│                                                    │
│ 2. Create AES-256-GCM cipher                       │
│    cipher = AES(derivedKey, mode: GCMMode)        │
│                                                    │
│ 3. Decrypt with tag verification                   │
│    plaintext = cipher.decrypt(                     │
│      ciphertext + tag,  // tag must match!         │
│      iv: iv                                        │
│    )                                               │
│    [GCM automatically verifies tag]                │
│                                                    │
│ 4. Decode plaintext                                │
│    return utf8.decode(plaintext)                   │
│                                                    │
│ 5. On failure:                                     │
│    - Wrong key? → garbled plaintext                │
│    - Tampered tag? → throw FormatException        │
│    - Garbled IV? → throw FormatException          │
└────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────┐
│ Method: deriveMasterKey(password: String,         │
│                         salt: String)             │
├────────────────────────────────────────────────────┤
│                                                    │
│ 1. Decode salt from hex                            │
│    saltBytes = hex.decode(salt)                    │
│                                                    │
│ 2. Run Argon2id key derivation                     │
│    key = await Argon2id(                           │
│      password: utf8.encode(password),              │
│      salt: saltBytes,                              │
│      parallelism: 1,                               │
│      memorySize: 65536 (64 MB)                     │
│      iterations: 2 (fast: ~200ms)                  │
│      hashLength: 32 (256 bits)                     │
│    ).call()                                        │
│                                                    │
│ 3. Return 32-byte key                              │
│    return key (Uint8List)                          │
│                                                    │
│ Performance:                                       │
│   ~200-300ms on modern phone                       │
│   Acceptable for one-time setup                    │
└────────────────────────────────────────────────────┘

Key Security Points:
✅ Nonce randomness: Random.secure()
✅ GCM tag verification: Automatic
✅ Key length: 256 bits (32 bytes)
✅ Salt: 16 bytes random
✅ Argon2id: Best for password hashing
✅ No hardcoded constants
```

---

## Diagrama 7: UI Flow (Wireframe Simplificado)

```
┌─────────────────────────────────────────────────┐
│ EntryDetailView                                 │
├─────────────────────────────────────────────────┤
│                                                 │
│  [← Back]  Title: "Twitter Password"    [⋮]    │
│                                                 │
│  ────────────────────────────────────────────   │
│                                                 │
│  Type:    Password                              │
│  Topic:   Social Media                          │
│                                                 │
│  Content:                                       │
│  │ My Twitter account password                  │
│                                                 │
│  Secret:                                        │
│  ┌────────────────────────────────────────────┐ │
│  │ 🔒 [REVEAL SECRET]                         │ │
│  └────────────────────────────────────────────┘ │
│  (visible only if requires_auth = true)         │
│                                                 │
│  ────────────────────────────────────────────   │
│  [Copy Content]  [Edit]  [Delete]              │
│                                                 │
└─────────────────────────────────────────────────┘
                        ↓ (User clicks REVEAL)
                        │
              ┌─────────▼──────────┐
              │ RevealSecretSheet  │
              │ (Bottom Modal)     │
              ├────────────────────┤
              │ Unlock Secret      │
              │                    │
              │ Password:          │
              │ ┌──────────────┐   │
              │ │ ••••••••••• │   │
              │ └──────────────┘   │
              │                    │
              │ [UNLOCK]  [CLOSE]  │
              └────────────────────┘
                        ↓ (User enters password & clicks UNLOCK)
                        │
              ┌─────────▼──────────┐
              │ Secret Visible:    │
              │ "MyPassword123!!"  │
              │                    │
              │ [Copy]  [Close]    │
              │                    │
              │ (Auto-hides 30s)   │
              └────────────────────┘

────────────────────────────────────────

┌─────────────────────────────────────────────────┐
│ CreateEntryForm                                 │
├─────────────────────────────────────────────────┤
│                                                 │
│  Title: ┌──────────────────────────────────┐   │
│         │ Twitter Password                 │   │
│         └──────────────────────────────────┘   │
│                                                 │
│  Type:  [Password ▼]                           │
│  Topic: [Social Media ▼]                       │
│                                                 │
│  Content:                                       │
│  ┌──────────────────────────────────────────┐  │
│  │ My private notes here                    │  │
│  └──────────────────────────────────────────┘  │
│                                                 │
│  Secret:                                        │
│  ┌──────────────────────────────────────────┐  │
│  │ MyPassword123!!                          │  │
│  └──────────────────────────────────────────┘  │
│                                                 │
│  ☐ Protect this entry                          │
│    (toggle to enable encryption)               │
│                                                 │
│  [Cancel]  [Save]                              │
│                                                 │
└─────────────────────────────────────────────────┘
                        ↓ (Toggle ON & click Save)
                        │
                   (First time?)
                        │
              ┌─────────▼──────────┐
              │MasterPasswordSetup │
              ├────────────────────┤
              │ Set Master         │
              │ Password           │
              │                    │
              │ Password:          │
              │ ┌──────────────┐   │
              │ │ ••••••••••• │   │
              │ └──────────────┘   │
              │                    │
              │ Confirm:           │
              │ ┌──────────────┐   │
              │ │ ••••••••••• │   │
              │ └──────────────┘   │
              │                    │
              │ [SET & PROTECT]    │
              └────────────────────┘
```

---

## Diagrama 8: Search Results with Protected Entries

```
┌──────────────────────────────────────────────────┐
│ SearchView                                       │
├──────────────────────────────────────────────────┤
│                                                  │
│  🔍 [search...____________________]              │
│                                                  │
│  Results for "password":                         │
│                                                  │
│  ┌─────────────────────────────────────────────┐│
│  │ Twitter Password            (Unprotected)   ││
│  │ Type: password                              ││
│  └─────────────────────────────────────────────┘│
│         ↓ Click to view
│
│  ┌─────────────────────────────────────────────┐│
│  │ 🔒 Gmail Password           (Protected)     ││
│  │ Type: password                              ││
│  │ Click [Reveal Secret] to unlock             ││
│  └─────────────────────────────────────────────┘│
│         ↓ Click to view → Needs unlock
│
│  ┌─────────────────────────────────────────────┐│
│  │ 🔒 Bank PIN                 (Protected)     ││
│  │ Type: secret                                ││
│  │ Click [Reveal Secret] to unlock             ││
│  └─────────────────────────────────────────────┘│
│
└──────────────────────────────────────────────────┘

FTS5 Index:
- Indexes ALL content (protected and unprotected)
- Shows 🔒 indicator for protected entries
- User must click [Reveal] to see decrypted content
- No leaked data in search results
```

---

## Summary: Architecture Highlights

| Componente | Aspecto | Detalle |
|-----------|---------|---------|
| **Criptografía** | Cifrado | AES-256-GCM (authenticated) |
| | Derivación | Argon2id(t=2, m=65536, p=1) |
| | Nonce | 12 bytes random per encryption |
| | Almacenamiento Key | Memory only (volatile) |
| **Data** | Schema | Append 4 columns + 1 new table |
| | Migration | Simple, no data transformation |
| | Backward Compat | ✅ Yes (all columns optional) |
| **Services** | Encrypt/Decrypt | EntryAuthService (1 service) |
| | State Mgmt | 3 Riverpod providers |
| | Dependencies | cryptography + pointycastle (2 new) |
| **UI** | Flows | Create, View, Search |
| | Interactions | Toggle protect, Reveal button, Auto-hide |
| **Performance** | Search | < 200 ms (no degradation) |
| | Decrypt | 2-5 ms per operation |
| | Argon2id | ~200-300 ms (one-time per session) |
| **Testing** | Coverage | 40-50 unit/integration tests |
| | Focus | Encrypt/decrypt, setup flow, UI |

---

**Documento:** `PHASE_2_ARCHITECTURE_DIAGRAMS_v2_SIMPLIFIED.md`  
**Fecha:** 2025  
**Responsable:** Architecture Team
