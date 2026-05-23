# Diagramas de Arquitectura — Fase 2: Cifrado y Vault Seguro

**Taúl Phase 2 — Architecture & Flows**

---

## 1. Diagrama de Capas (Layered Architecture)

```
┌─────────────────────────────────────────────────────────────────┐
│                         PRESENTATION LAYER                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  UnlockScreen          MainSearchScreen      EntryDetailScreen  │
│  (contraseña/bio)      (búsqueda FTS5)       (decrypt + show)   │
│       │                      │                       │           │
│       └──────────────────────┼───────────────────────┘           │
│                              │                                   │
└──────────────────────────────┼───────────────────────────────────┘
                               │
┌──────────────────────────────▼───────────────────────────────────┐
│                    RIVERPOD STATE LAYER                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  masterKeyProvider (StateNotifier)  [clave en memoria, volátil]  │
│  sessionProvider (StateNotifier)    [token + expiración]         │
│  currentEntryProvider (Future)      [entry actual + context]     │
│  appStateProvider (watch)           [controla unlock redirect]   │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
                               │
┌──────────────────────────────▼───────────────────────────────────┐
│                      DOMAIN LAYER (UseCases)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  CreateCredentialUseCase                                         │
│  ├── input: title, username, secret, masterKey                  │
│  └── output: encryptedEntry                                     │
│                                                                   │
│  GetDecryptedEntryUseCase                                        │
│  ├── input: entryId, masterKey                                  │
│  └── output: decrypted plaintext secret                         │
│                                                                   │
│  UnlockVaultUseCase                                             │
│  ├── input: password, salt                                      │
│  └── output: masterKey (or error)                               │
│                                                                   │
│  SearchEntriesUseCase (sin descifrado)                          │
│  ├── input: query                                               │
│  └── output: FTS5 results (secrets aún cifrados)               │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
                               │
┌──────────────────────────────▼───────────────────────────────────┐
│              INFRASTRUCTURE LAYER (Services + Repositories)       │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌────────────────────────┐   ┌─────────────────────────────┐   │
│  │   CryptoService        │   │  EntryRepository + EntryDAO │   │
│  ├────────────────────────┤   ├─────────────────────────────┤   │
│  │ + encrypt()            │   │ + create(entry)             │   │
│  │ + decrypt()            │   │ + createWithSecret()        │   │
│  │ + deriveMasterKey()    │   │ + getDecrypted()            │   │
│  │ + generateSalt()       │   │ + updateSecret()            │   │
│  │ + validateNonce()      │   │ + search() [FTS5]           │   │
│  │ + validateTag()        │   │ + delete()                  │   │
│  └────────────────────────┘   └─────────────────────────────┘   │
│                                                                   │
│  ┌────────────────────────┐   ┌─────────────────────────────┐   │
│  │ BiometricService       │   │ SecureStorageService        │   │
│  ├────────────────────────┤   ├─────────────────────────────┤   │
│  │ + isAvailable()        │   │ + setMasterKey()            │   │
│  │ + authenticate()       │   │ + getMasterKey()            │   │
│  │ + canAuthenticate()    │   │ + setSalt()                 │   │
│  │ + enableBiometric()    │   │ + getSalt()                 │   │
│  │ + disableBiometric()   │   │ + setSessionToken()         │   │
│  │ + isBiometricEnabled() │   │ + getSessionToken()         │   │
│  │                        │   │ + deleteSessionToken()      │   │
│  └────────────────────────┘   └─────────────────────────────┘   │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
                               │
┌──────────────────────────────▼───────────────────────────────────┐
│                   DATA LAYER (Drift + SQLite)                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  entries (v2)           [id, type, title, content, secret,      │
│                          secret_nonce, secret_tag, ...]         │
│                                                                   │
│  crypto_config          [salt_hex, crypto_version,              │
│                          master_key_hash, created_at]           │
│                                                                   │
│  sessions               [id, created_at, expires_at, is_active] │
│                                                                   │
│  fts5_entries_idx       [title, content, tags, type]            │
│                         (sin secret indexado)                    │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

---

## 2. Flujo de Inicio de Sesión (Unlock Flow)

```
┌──────────────────────────────────────────────────────────────┐
│  App inicia: main() → runApp(TaulApp())                      │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
        ┌──────────────────────────────────┐
        │  SessionProvider.watch()         │
        │  ¿Hay token válido en memoria?  │
        └──────┬──────────────────┬────────┘
               │                  │
         SÍ (token exists)    NO (token == null)
               │                  │
               │                  ▼
               │        ┌──────────────────────────────────┐
               │        │ ¿Hay sesión en secure_storage?   │
               │        └──────┬──────────────────┬─────────┘
               │               │                  │
               │          SÍ   │              NO  │
               │               │                  │
               │               ▼                  ▼
               │        ┌─────────────────┐  ┌──────────────────┐
               │        │ Cargar token a  │  │ ShowUnlockScreen │
               │        │ memoria         │  │                  │
               │        └────────┬────────┘  │ Usuario elije:   │
               │                 │           │ a) Biométrico    │
               │                 │           │ b) Contraseña    │
               │                 │           └────────┬─────────┘
               │                 │                    │
               │                 │         ┌──────────┴──────────┐
               │                 │         │                     │
               │                 │         ▼                     ▼
               │                 │    ┌─────────────┐  ┌──────────────────┐
               │                 │    │Biometric    │  │ Password Input   │
               │                 │    │authenticate │  │                  │
               │                 │    └──────┬──────┘  │ deriv: Argon2id  │
               │                 │           │         │ validate vs hash │
               │                 │           │         └────────┬─────────┘
               │                 │           │                  │
               │                 │    ┌──────┴──────────┐       │
               │                 │    │                 │       │
               │                 │    ▼ (OK o ERROR)   ▼ (OK o ERROR)
               │                 │    ┌─────────────────────────┐
               │                 │    │ masterKey OK?           │
               │                 │    │ (derivación exitosa)    │
               │                 │    └──────┬──────────┬────────┘
               │                 │           │          │
               │                 │           │     ERROR
               │                 │           │     (show snackbar, retry)
               │                 │           │
               │                 │     masterKey derivado
               │                 │           │
               │                 ▼           ▼
               │    ┌─────────────────────────────────┐
               │    │ Guardar:                        │
               │    │ - masterKey a masterKeyProvider │
               │    │ - token a sessionProvider       │
               │    │ - token a secure_storage        │
               │    └────────────────┬────────────────┘
               │                     │
               ▼                     ▼
        ┌──────────────────────────────────┐
        │ StartSessionTimer(15 min)        │
        │ ┌──────────────────────────────┐ │
        │ │ On Activity: Restart Timer   │ │
        │ │ On 14 min: ShowTimeoutDialog │ │
        │ │ On 15 min: Logout + Redirect │ │
        │ └──────────────────────────────┘ │
        └────────────────┬─────────────────┘
                         │
                         ▼
        ┌──────────────────────────────────┐
        │ MainSearchScreen (ir)            │
        │ FTS5 búsqueda + decrypt on-click │
        └──────────────────────────────────┘
```

---

## 3. Flujo de Cifrado de Credencial (Create Secret)

```
┌─────────────────────────────────────────────────────────────┐
│ Usuario: "Crear credencial"                                │
│ Input: { title, username, secret_plaintext }              │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
      ┌──────────────────────────────────┐
      │ masterKeyProvider.read()         │
      │ ¿Está la clave en memoria?       │
      └──────┬──────────────────┬────────┘
             │                  │
        YES  │              NO  │
             │                  │
             │                  ▼
             │         ┌────────────────────┐
             │         │SessionExpiredException│
             │         │ (redirect to unlock)   │
             │         └────────────────────┘
             │
             ▼
      ┌──────────────────────────────────┐
      │ CryptoService.encrypt()          │
      │                                  │
      │ Inputs:                          │
      │  - plaintext: secret_plaintext   │
      │  - masterKey: masterKeyProvider  │
      │  - nonce: crypto.Random(12 bytes)│
      │                                  │
      │ Outputs:                         │
      │  - ciphertext (bytes)            │
      │  - tag (16 bytes, GCM)           │
      │  - nonce (12 bytes)              │
      │  - crypto_version (int)          │
      └──────────────┬───────────────────┘
                     │
                     ▼
      ┌──────────────────────────────────┐
      │ Base64 encode:                   │
      │ - secret = base64(ciphertext)    │
      │ - secret_nonce = hex(nonce)      │
      │ - secret_tag = hex(tag)          │
      │ - crypto_version = 1             │
      └──────────────┬───────────────────┘
                     │
                     ▼
      ┌──────────────────────────────────┐
      │ EntryRepository.createWithSecret()
      │                                  │
      │ INSERT INTO entries (            │
      │   id, type, title, content,      │
      │   secret, secret_nonce,          │
      │   secret_tag, crypto_version,    │
      │   created_at, ...                │
      │ ) VALUES (...)                   │
      └──────────────┬───────────────────┘
                     │
                     ▼
      ┌──────────────────────────────────┐
      │ ✅ Credencial guardada cifrada   │
      │ Retornar a MainSearchScreen      │
      └──────────────────────────────────┘
```

---

## 4. Flujo de Descifrado de Entrada (Get Decrypted)

```
┌─────────────────────────────────────────────────────────────┐
│ Usuario: Abre credencial desde búsqueda                    │
│ Input: entryId = "abc123"                                  │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
      ┌──────────────────────────────────┐
      │ masterKeyProvider.read()         │
      │ ¿Está la clave en memoria?       │
      └──────┬──────────────────┬────────┘
             │                  │
        YES  │              NO  │
             │                  │
             │                  ▼
             │         ┌────────────────────┐
             │         │SessionExpired      │
             │         │(redirect unlock)   │
             │         └────────────────────┘
             │
             ▼
      ┌──────────────────────────────────┐
      │ EntryRepository.getDecrypted()   │
      │                                  │
      │ 1. SELECT * FROM entries         │
      │    WHERE id = 'abc123'           │
      │                                  │
      │ 2. rows[0] = {                   │
      │      secret: "base64...",        │
      │      secret_nonce: "hex...",     │
      │      secret_tag: "hex...",       │
      │      crypto_version: 1,          │
      │      ...                         │
      │    }                             │
      └──────────────┬───────────────────┘
                     │
                     ▼
      ┌──────────────────────────────────┐
      │ Base64/Hex decode:               │
      │ - ciphertext = base64Decode(row) │
      │ - nonce = hexDecode(row.nonce)   │
      │ - tag = hexDecode(row.tag)       │
      └──────────────┬───────────────────┘
                     │
                     ▼
      ┌──────────────────────────────────┐
      │ CryptoService.decrypt()          │
      │                                  │
      │ Inputs:                          │
      │  - ciphertext (bytes)            │
      │  - nonce (12 bytes)              │
      │  - tag (16 bytes)                │
      │  - masterKey (from provider)     │
      │                                  │
      │ Validates:                       │
      │  - nonce length == 12?           │
      │  - tag length == 16?             │
      │  - GCM authentication            │
      │                                  │
      │ Returns:                         │
      │  - plaintext (if OK)             │
      │  - CryptoException (if invalid)  │
      └──────────────┬───────────────────┘
                     │
         ┌───────────┴────────────┐
         │                        │
        OK                    ERROR
         │                        │
         ▼                        ▼
   ┌──────────────┐        ┌──────────────────┐
   │ plaintext    │        │ CryptoException  │
   │ (secret OK)  │        │ (tampering?)     │
   └──────┬───────┘        │ Show error dialog│
          │                └──────────────────┘
          ▼
   ┌──────────────────────────────────┐
   │ Mostrar en EntryDetailScreen:    │
   │ - title: "[credencial name]"     │
   │ - username: [visible]            │
   │ - secret: [visible, con botón    │
   │           de "copy to clipboard] │
   │ - tag: "Copied! (30s timeout)"   │
   └──────────────────────────────────┘
```

---

## 5. Flujo de Migración v1 → v2

```
┌────────────────────────────────────────────────────┐
│ App actualiza de v1.0 a v2.0                      │
│ Usuario abre app por primera vez con v2           │
└────────────────┬─────────────────────────────────┘
                 │
                 ▼
      ┌──────────────────────────────────┐
      │ Drift: Detectar DB version       │
      │                                  │
      │ SELECT * FROM sqlite_master      │
      │ WHERE name = 'crypto_config'     │
      │ ¿Tabla existe?                   │
      └──────┬──────────────────┬────────┘
             │                  │
          NO │             YES  │
             │                  │
             │                  ▼
             │      ┌──────────────────┐
             │      │ Ya está migrada  │
             │      │ (ir a unlock)    │
             │      └──────────────────┘
             │
             ▼
      ┌──────────────────────────────────┐
      │ INICIO MIGRACIÓN v1 → v2         │
      │                                  │
      │ 1. Crear backup:                 │
      │    - taul_backup_v1_<ts>.zst     │
      │    - Copiar a backup/ dir        │
      └──────────────┬───────────────────┘
                     │
                     ▼
      ┌──────────────────────────────────┐
      │ 2. Mostrar UI: "SetupSecurity"   │
      │    "Protege tus credenciales"    │
      │    - Input: contraseña nueva     │
      │    - Confirm: repetir            │
      │    - checkbox: "Usar biométrico" │
      └──────────────┬───────────────────┘
                     │
                     ▼
      ┌──────────────────────────────────┐
      │ 3. Generar salt aleatorio:       │
      │    salt = crypto.Random(16 bytes)│
      │    salt_hex = hex(salt)          │
      └──────────────┬───────────────────┘
                     │
                     ▼
      ┌──────────────────────────────────┐
      │ 4. Derivar masterKey:            │
      │    masterKey = Argon2id(         │
      │      password=user_input,        │
      │      salt=salt_hex,              │
      │      t=3, m=65536, p=4           │
      │    )                             │
      │    master_key_hash = SHA256(key) │
      └──────────────┬───────────────────┘
                     │
                     ▼
      ┌──────────────────────────────────┐
      │ 5. Guardar crypto_config:        │
      │    INSERT INTO crypto_config (   │
      │      salt_hex, crypto_version,   │
      │      master_key_hash, created_at │
      │    ) VALUES (...)                │
      └──────────────┬───────────────────┘
                     │
                     ▼
      ┌──────────────────────────────────┐
      │ 6. Almacenar en secure_storage:  │
      │    - salt a SecureStorageService │
      │    - master_key (volátil)        │
      │    - biometric setting (si user) │
      └──────────────┬───────────────────┘
                     │
                     ▼
      ┌──────────────────────────────────┐
      │ 7. Alterar schema de DB:         │
      │    ALTER TABLE entries ADD       │
      │      secret_nonce TEXT;          │
      │    ALTER TABLE entries ADD       │
      │      secret_tag TEXT;            │
      │    ALTER TABLE entries ADD       │
      │      crypto_version INT DEFAULT 1;
      └──────────────┬───────────────────┘
                     │
                     ▼
      ┌──────────────────────────────────┐
      │ 8. Re-cifrar todos los secrets:  │
      │                                  │
      │    FOR EACH entry WITH secret:   │
      │     - ciphertext = AES256GCM(    │
      │         secret_plaintext,        │
      │         masterKey)               │
      │     - UPDATE entries SET         │
      │         secret=base64(ct),       │
      │         secret_nonce=hex(nonce), │
      │         secret_tag=hex(tag)      │
      │                                  │
      │    [Progress bar: X de Y]        │
      └──────────────┬───────────────────┘
                     │
                     ▼
      ┌──────────────────────────────────┐
      │ 9. Crear índices FTS5 v2:        │
      │    CREATE VIRTUAL TABLE          │
      │    fts5_entries_idx (            │
      │      title, content, tags        │
      │    ) [NO secret]                 │
      └──────────────┬───────────────────┘
                     │
                     ▼
      ┌──────────────────────────────────┐
      │ 10. Crear tabla sessions:        │
      │    CREATE TABLE sessions (...)   │
      └──────────────┬───────────────────┘
                     │
                     ▼
      ┌──────────────────────────────────┐
      │ 11. Validar integridad:          │
      │     - SHA256(all entries)        │
      │     - Checksum match?            │
      │     - Count de secrets == Before?│
      └──────┬──────────────────┬────────┘
             │                  │
          OK │              ERROR│
             │                  │
             │                  ▼
             │         ┌────────────────────┐
             │         │ MigrationException │
             │         │ Restaurar backup   │
             │         │ Error UI + retry   │
             │         └────────────────────┘
             │
             ▼
      ┌──────────────────────────────────┐
      │ ✅ MIGRACIÓN EXITOSA             │
      │ Guardar version en preferences   │
      │ Ir a UnlockScreen (primer unlock)│
      └──────────────────────────────────┘
```

---

## 6. Flujo de Cierre de Sesión por Timeout

```
┌────────────────────────────────────────────┐
│ Sesión activa: masterKey en memoria        │
│ Timer: 15 min desde última actividad       │
└────────────────┬──────────────────────────┘
                 │
        [Mientras pasan los minutos]
                 │
    ┌────────────┴──────────┐
    │                       │
    ▼                       ▼
 [14:00] Actividad    [14:50] Silencio
 (touch, click)       (timer llega)
    │                       │
    │ (Restart timer)       │
    │                       ▼
    │          ┌──────────────────────────────┐
    │          │ ALERTA: Sesión cerrarse en   │
    │          │ 1 minuto                     │
    │          │                              │
    │          │ [Renovar] [Cerrar Ahora]    │
    │          └──────┬──────────────────┬────┘
    │                 │                  │
    │            USER  │              USER│
    │            TAPS   │              TAPS
    │                 │                  │
    │                 ▼                  ▼
    │          [Restart timer]    ┌──────────────┐
    │          [Volver a 15 min] │ Logout       │
    │                             │ (próximo paso)
    │                             └──────────────┘
    │                                    │
    └────────────────────────────────────┘
                     │
                     ▼
         [15:00] Timer finaliza
         (no hay actividad en 15 min)
                     │
                     ▼
      ┌──────────────────────────────────┐
      │ TIMEOUT LOGIC:                   │
      │                                  │
      │ 1. masterKeyProvider.clear()     │
      │ 2. sessionProvider.clear()       │
      │ 3. sessionToken eliminar         │
      │ 4. Mostrar SnackBar: "Sesión"    │
      │    "cerrada por seguridad"       │
      └──────────────┬───────────────────┘
                     │
                     ▼
      ┌──────────────────────────────────┐
      │ go_router.replace('/unlock')     │
      │ (volver a UnlockScreen)          │
      └──────────────────────────────────┘
```

---

## 7. Estado de Providers Riverpod (Diagrama de Estado)

```
┌─────────────────────────────────────────────────────────────┐
│ RIVERPOD STATE MACHINE (Transiciones)                      │
└─────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────┐
│  STATE: LOCKED (App inicia, no session)   │
├───────────────────────────────────────────┤
│ masterKeyProvider: null                   │
│ sessionProvider: null                     │
│ ui_state: UnlockScreen (mostrar)          │
└────────┬────────────────────────┬─────────┘
         │                        │
      [Auth OK]              [Auth FAIL]
         │                        │
         ▼                        ▼
┌───────────────────────────────────┐  ┌──────────────────┐
│ masterKey = deriveMasterKey()     │  │ Show error       │
│ (Argon2id)                        │  │ Volver a LOCKED  │
└────────┬────────────────────────────┘  └──────────────────┘
         │
         ▼
┌───────────────────────────────────┐
│ STATE: UNLOCKING                  │
├───────────────────────────────────┤
│ masterKeyProvider: Setting...     │
│ sessionProvider: Generating...    │
│ ui_state: Loading                 │
└────────┬────────────────────────────┘
         │
         ▼
┌───────────────────────────────────┐
│ STATE: UNLOCKED (session valid)   │
├───────────────────────────────────┤
│ masterKeyProvider: bytes (volátil)│
│ sessionProvider: token + expires  │
│ ui_state: MainSearchScreen        │
│ sessionTimer: active (15 min)     │
└────────┬───────────────────────────┘
         │
    ┌────┴─────────────────────┐
    │                          │
 [Activity]              [Timeout/Logout]
    │                          │
    │ (Restart timer)          ▼
    │                   ┌──────────────────┐
    │                   │ Clear providers  │
    │                   │ Delete session   │
    │                   │ token            │
    │                   └────┬─────────────┘
    │                        │
    └────────────────────────┴──────▶ STATE: LOCKED
```

---

## 8. Matriz de Componentes y Responsabilidades

```
┌────────────────────────────────────────────────────────────────┐
│ COMPONENTS & RESPONSIBILITIES                                 │
├────────────────────────────────────────────────────────────────┤

CryptoService
├── ✅ Cifrado/Descifrado AES-256-GCM
├── ✅ Derivación de clave Argon2id
├── ✅ Generación de salt/nonce
├── ✅ Validación de nonce/tag
├── ❌ NO almacenar secretos
├── ❌ NO conocer DB
└── ❌ NO hacer I/O

BiometricService
├── ✅ Consultar disponibilidad local_auth
├── ✅ Autenticar con biométricos
├── ✅ Habilitar/deshabilitar
├── ❌ NO almacenar datos biométricos
├── ❌ NO comunicarse remotamente
└── ❌ NO acceder a DB

SecureStorageService
├── ✅ Guardar masterKey en flutter_secure_storage
├── ✅ Guardar salt
├── ✅ Guardar session token
├── ✅ Recuperar valores almacenados
├── ✅ Limpiar valores al logout
├── ❌ NO hacer lógica criptográfica
└── ❌ NO acceder a DB

EntryRepository
├── ✅ CRUD de entries
├── ✅ createWithSecret(entry, masterKey) [cifra]
├── ✅ getDecrypted(id, masterKey) [descifra]
├── ✅ updateSecret(id, newSecret, masterKey)
├── ✅ search() vía FTS5 (sin descifrado)
├── ✅ Coordinar con CryptoService
├── ❌ NO derivar claves
└── ❌ NO conocer biométricos

SessionProvider (Riverpod)
├── ✅ Guardar token en memoria
├── ✅ Guardar expiración
├── ✅ Notificar cambios
├── ✅ Trigger timeout
├── ❌ NO hacer criptografía
└── ❌ NO hacer I/O directo

MasterKeyProvider (Riverpod)
├── ✅ Guardar clave en memoria (volátil)
├── ✅ Notificar disponibilidad
├── ✅ Vaciar al logout
├── ❌ NO persistir a disco
├── ❌ NO hacer criptografía
└── ❌ NO conocer BD
```

---

## 9. Error Handling Flowchart

```
┌──────────────────────────────────────────┐
│ Operación Criptográfica Falla            │
└────────────┬─────────────────────────────┘
             │
      ┌──────┴───────┬──────────┬──────────┐
      │              │          │          │
      ▼              ▼          ▼          ▼
  CryptoEx      SessionEx   BiometricEx  StorageEx
  (decrypt)     (timeout)   (auth fail)  (unavail)
      │              │          │          │
      ▼              ▼          ▼          ▼
   ┌─────────────────────────────────────────────┐
   │ Log: error info (sin datos sensibles)       │
   └─────────────────────────────────────────────┘
      │
      ├─────────────────────────────────────────┐
      │                                         │
      ▼                                         ▼
  User-facing                          Auto Recovery
  Error Dialog                          (si posible)
      │
      ├─ "Credencial                  ├─ Retry timeout
      │   corrupta"                    ├─ Fallback auth
      │                                ├─ Switch method
      ├─ "Sesión expirada"            └─ Use backup
      │  (Mostrar dialog
      │   de re-unlock)
      │
      ├─ "Datos sensibles"
      │  "indisponibles"
      │
      └─ Sugerir acciones
         - Contactar soporte
         - Restaurar backup

Cada excepción:
- Capturada en UI (widget builder o usecase)
- Mostrada en SnackBar o Dialog
- Logeada sin PII
- Opción de "Contactar Soporte"
- Opción de "Restaurar desde Backup"
```

---

## 10. Diagrama de Decisión: ¿Requiere Unlock?

```
┌─────────────────────────────────┐
│ Usuario intenta operación       │
│ (crear, leer, actualizar secret)│
└─────────────┬───────────────────┘
              │
              ▼
      ┌──────────────────────────┐
      │ ¿Hay masterKey en memoria│
      │ (masterKeyProvider)?     │
      └──────┬──────────┬────────┘
             │          │
           YES         NO
             │          │
             ▼          ▼
        ┌────────┐  ┌────────────────┐
        │OK      │  │SessionExpired  │
        │Procede │  │Exception       │
        │        │  │               │
        │ ALLOW  │  │ Redirect:     │
        │ OP     │  │ /unlock       │
        └────────┘  │               │
                    │ BLOCK OP      │
                    └────────────────┘
```

---

**Fin de Diagramas de Arquitectura**
