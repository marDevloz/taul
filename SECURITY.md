# Security Architecture

## Master Password Protection

Taúl uses a **wrapping key pattern (KEK/DEK)** to protect credentials without
requiring password re-entry for every operation.

### Key Hierarchy

```
┌──────────────────────────────────────────────┐
│          Master Password (user-provided)       │
│                     ↓                          │
│         Argon2id(password, salt)               │
│                     ↓                          │
│         Key Encryption Key (KEK) ─────┐        │
│                                       │ encrypt │
│           Data Encryption Key (DEK) ──┘        │
│           (random 32 bytes)                    │
│                                       │        │
│           ┌───────────────────────────┘        │
│           ↓                                    │
│     encryptedStorageKey (stored in DB)         │
│                                                 │
│     Per-entry:                                  │
│     AES-256-GCM.encrypt(secret, key=DEK)       │
└──────────────────────────────────────────────┘
```

| Key | Length | Storage | Purpose |
|-----|--------|---------|---------|
| MP | Variable | RAM only | User-provided, never stored |
| KEK | 32 bytes | Derived on demand, never stored | Wraps/unwraps DEK |
| DEK | 32 bytes | Encrypted at rest (wrapped with KEK) | Encrypts/decrypts entry secrets |

### Benefits

- **MP changes are instant** — only the DEK is re-wrapped with the new KEK.
  No entry re-encryption needed.
- **No plaintext keys on disk** — DEK is stored encrypted with KEK,
  which itself is derived from the user's password via Argon2id.
- **Transparent encryption** — once unlocked, the DEK is cached in RAM
  and used silently for all encrypt/decrypt operations.

## Backup Codes

During MP setup, **10 single-use backup codes** are generated for offline
recovery.

### Format and Storage

| Aspect | Detail |
|--------|--------|
| Format | `XXXX-XXXX` (8 alphanumeric chars, uppercase) |
| Count | Exactly 10 |
| Storage | Argon2id hashed, each with its own 8-byte random salt |
| Salt storage | Stored as `salt_hex:hash_hex` in a JSON array |
| Display | Shown exactly once after setup/regeneration |

### Verification Flow

```sql
BEGIN TRANSACTION
  1. Parse backup_code_hashes JSON → List<"salt:hash">
  2. For each entry: Argon2id(code, salt) → compare with hash
  3. If match at index i: splice from list
  4. Serialize updated list → JSON
  5. UPDATE master_password_config SET backup_code_hashes = ?
COMMIT
```

- **Atomic consumption**: verify + delete in a single transaction.
  If the DB write fails, the code hash is NOT removed — safe to retry.
- **Second use**: after consumption, the hash is gone from the array.
  The same code will never match again.

## Recovery Flow

When a user forgets their master password:

1. Tap "Forgot password?" at the reveal prompt
2. Enter a backup code
3. Code is verified against stored Argon2id hashes
4. On match: code is consumed atomically
5. User sets a new master password

**Important**: Recovery generates a **new DEK** because the old DEK is
encrypted with a KEK derived from the forgotten password. Without the old
password, the old KEK cannot be derived. This means entries encrypted with
the old DEK become **unreachable**.

## Schema Migration (v2 → v3)

```sql
ALTER TABLE master_password_config
  ADD COLUMN password_hint TEXT;

ALTER TABLE master_password_config
  ADD COLUMN backup_code_hashes TEXT;

ALTER TABLE master_password_config
  ADD COLUMN encrypted_storage_key TEXT;

ALTER TABLE master_password_config
  ADD COLUMN encrypted_storage_key_nonce TEXT;

ALTER TABLE master_password_config
  ADD COLUMN encrypted_storage_key_tag TEXT;
```

All columns are **nullable** — existing v2 rows migrate without data loss.

## Crypto Primitives

| Operation | Algorithm | Parameters |
|-----------|-----------|------------|
| Key derivation | Argon2id | memory=65536, iterations=2, parallelism=1 |
| Key length | AES-256 | 32 bytes (256 bits) |
| Encryption | AES-256-GCM | 12-byte random nonce, 16-byte MAC tag |
| Salt | CSPRNG | 16 bytes per MP, 8 bytes per backup code |
| Random source | `dart:math Random.secure()` | Platform CSPRNG |

## Rate Limiting

| Scenario | Limit | Implementation |
|----------|-------|---------------|
| Wrong MP attempts | 5 attempts → 30s lockout | In-memory counter + timestamp |
| Wrong backup code | 3 attempts → 60s lockout | In-memory counter + timestamp |

Rate limits are in-memory only — survive navigation but not app restart.
Acceptable for an offline app where primary protection is Argon2id.

## Threats Mitigated

| Threat | Mitigation |
|--------|-----------|
| Device stolen, DB extracted | All credentials encrypted with AES-256-GCM |
| Attacker reads DB file | Keys are never stored plaintext |
| Attacker tries to guess MP | Argon2id memory-hard KDF (~1.5s per attempt) |
| Attacker reuses a backup code | Atomic consumption — single use per code |
| Attacker cracks one code | Each code has unique salt — no batch cracking |
| Attacker rainbow-tables codes | Argon2id with per-code salt prevents precomputation |
| Session replay after MP change | DEK is cleared from cache on change |

## What We DO NOT Store

| Never stored | Reason |
|-------------|--------|
| Plain backup codes | Shown once, user must save externally |
| Master password in plaintext | Only KEK derived via Argon2id |
| DEK in plaintext on disk | Encrypted with KEK at rest |
| Session tokens | Offline-only app |

## Security Warnings (shown to user)

1. **Hint is stored as plaintext**: visible to anyone with device access.
2. **Backup codes shown once**: after dismissal, they cannot be re-displayed.
   User must save them externally (password manager, safe).
3. **Delete MP warning**: protected entries become permanently unreachable.
4. **Without MP or backup code**: protected data is unrecoverable — no
   backdoor, no reset, no support.
