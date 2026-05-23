# Propuesta SDD – Fase 2 (v2): Protección Opcional de Entradas

**Taúl — Almacenamiento Personal Minimalista, Rápido y Seguro**

**Versión:** 2.1-Phase2-Proposal-Simplified  
**Fecha:** 2025  
**Estado:** 🟡 Propuesta — Pendiente Aprobación  
**Responsable:** Equipo de Arquitectura  

---

## 🎯 Resumen Ejecutivo (Una Frase)

**Permitir que usuarios protejan entradas individuales con una contraseña maestra única, sin fricción global.**

---

## 📊 Snapshot Ejecutivo

| Aspecto | Detalle |
|--------|---------|
| **Problema** | Credenciales sensibles están en texto plano; usuarios quieren protección *selectiva*, no global |
| **Solución** | `Entry.requiresAuth` boolean + una contraseña maestra por usuario + AES-256-GCM |
| **Stack Nuevo** | `cryptography` + `pointycastle` (NO vault, NO flutter_secure_storage, NO session timeout global) |
| **Cambios BD** | +4 columnas (requiresAuth, encryptedSecret, cipherNonce, cipherTag) + 1 tabla config |
| **Esfuerzo** | **~20 horas (~1 semana, 1 person)** |
| **Estimación** | 🟢 **LOW** |
| **Riesgo Mayor** | Minimal (sin migración compleja, sin timeout, sin vault state) |
| **Beneficio** | ✅ Protección granular, zero friction, user-centric |

---

## 1. Intent (Problema, Por Qué Ahora, Qué Éxito)

### 1.1 Problema

**Anterior (Fase 1 - RESUELTO):**
- ✅ CRUD funcional
- ✅ Búsqueda rápida (FTS5)

**Actual (Fase 2 - NUEVO):**
- ❌ Algunos secretos son críticos (contraseñas, tokens) → necesitan cifrado
- ❌ Pero NO todos los datos necesitan protección global → fricción innecesaria
- ❌ Usuario quiere elegir **qué** proteger, no que TODO esté bajo vault

**Riesgo:** Si alguien accede al archivo `.db`, puede leer las contraseñas.

### 1.2 Por Qué Ahora

1. **Feedback de usuarios (hipotético):** "Quiero proteger mis contraseñas sin que me pida contraseña cada vez que busco notas"
2. **Phase 1 es estable:** Base sólida para agregar selectividad
3. **Simplificar futura sincronización (Phase 3):** Datos protegidos ya están encriptados antes de sincronización

### 1.3 Definición de Éxito

✅ **La Fase 2 se considera exitosa cuando:**

1. Usuario puede crear/editar entrada con `requiresAuth = true`
2. Contraseña maestra se crea UNA SOLA VEZ (primera protección)
3. Al ver entrada protegida → pide contraseña → descifra → muestra secret → auto-oculta 30s
4. Búsqueda FTS5 sigue siendo rápida (< 200 ms)
5. Todos los entry types pueden ser protegidos (`note`, `password`, `secret`, `url`, etc.)
6. Encriptación es AES-256-GCM + Argon2id
7. Sin timeout global, sin vault state, sin biometría (future)

**Métrica clave:** Funcionalidad en < 1 semana, 20 horas, 1 persona.

---

## 2. Scope Detallado (IN / OUT)

### 2.1 IN-SCOPE ✅

#### 2.1.1 Data Model
- **Entry.requiresAuth** (boolean, default false)
- **Entry.encryptedSecret** (string nullable)
- **Entry.cipherNonce** (string nullable)
- **Entry.cipherTag** (string nullable)
- Todos los entry types (`note`, `password`, `secret`, `url`, etc.) pueden ser protegidos

#### 2.1.2 Cifrado
- **AES-256-GCM** para `secret` cuando `requiresAuth = true`
- **Argon2id** derivación de clave maestra (parámetros simples)
- **Nonce aleatorio** por cada cifrado (IV)
- **Autenticación GCM** incluida (nonce + tag)

#### 2.1.3 Gestión de Contraseña Maestra
- **Una sola contraseña global** para TODAS las entradas protegidas
- **Pregunta UNA SOLA VEZ:** Al proteger la primera entrada
- **Almacenamiento:** Tabla `master_password_config` con hash Argon2id (NO secure_storage)
- **En memoria:** Clave derivada se guarda en sesión (Riverpod state)

#### 2.1.4 Flows de Usuario

**Create/Edit Entry:**
```
User escribe entrada normal
  ↓
Toggle "Protect this entry?" → ON
  ↓
Si es primera vez:
  → Pide contraseña maestra (input 1x)
  → Guarda hash en master_password_config
  ↓
Encripta secret
  ↓
Guarda entry con (requiresAuth, encryptedSecret, nonce, tag)
```

**View Entry:**
```
Click en entry con requiresAuth=true
  ↓
"Reveal Secret" button
  ↓
Pide contraseña maestra (input)
  ↓
Verifica hash Argon2id
  ↓
Descifra secret
  ↓
Muestra secret en overlay
  ↓
Auto-oculta después 30s
  ↓
User puede hacer copy-paste durante esos 30s
```

**Search (FTS5):**
```
User busca "twitter"
  ↓
FTS5 busca en encrypted secrets también
  ↓
Resultados muestran entry con indicador "🔒 (Protected)"
  ↓
Si user click → muestra "Reveal Secret" button
```

#### 2.1.5 Servicios (MÍNIMOS)

**EntryAuthService** (solo método):
```dart
class EntryAuthService {
  // Derivar clave de password + salt
  Future<Uint8List> deriveMasterKey(String password, String salt) 
    → Argon2id

  // Encriptar 1 secret
  Future<EncryptionResult> encrypt(String plaintext, Uint8List masterKey)
    → {encryptedSecret, nonce, tag}

  // Descifrar 1 secret
  Future<String> decrypt(String encryptedSecret, String nonce, String tag, 
                         Uint8List masterKey)
    → plaintext

  // Generar salt aleatorio
  String generateSalt() → 16 bytes hex

  // Hash contraseña (verificación)
  String hashPassword(String password, String salt) → Argon2id hex
}
```

**NO BiometricService** (future, Phase 2.1)  
**NO SecureStorageService** (guardamos hash en BD, no necesitamos)  
**NO SessionService** (no hay session timeout)

#### 2.1.6 Schema BD (v1 → v2)

```sql
-- Table entries (MODIFICADA)
ALTER TABLE entries ADD COLUMN requires_auth BOOLEAN DEFAULT 0;
ALTER TABLE entries ADD COLUMN encrypted_secret TEXT;
ALTER TABLE entries ADD COLUMN cipher_nonce TEXT;
ALTER TABLE entries ADD COLUMN cipher_tag TEXT;

-- Table NEW: master_password_config
CREATE TABLE master_password_config (
  id INTEGER PRIMARY KEY,
  password_hash_argon2 TEXT NOT NULL,  -- Argon2id hash
  salt_hex TEXT NOT NULL,               -- 16 bytes random, hex encoded
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
-- Hay 0 o 1 row en esta tabla
```

#### 2.1.7 Riverpod Providers (MÍNIMOS)

1. **entryAuthServiceProvider**
   - Instancia única de `EntryAuthService`

2. **masterPasswordProvider** (StateNotifier)
   - State: `Uint8List? derivedKey` (en memoria, durante sesión)
   - `setMasterPassword(password)` → derive key, store in state
   - `clearMasterPassword()` → null
   - `isMasterPasswordSet()` → bool

3. **unlockedEntriesProvider** (StateNotifier)
   - Set de IDs de entries que fueron descifradas en esta sesión
   - Auto-limpiar después 30s por entry (elegir mejor UX luego)

#### 2.1.8 UI Mínima

**EntryDetailView:**
- Si `requiresAuth = true` → botón "[🔒 Reveal Secret]"
- Click → overlay con password input
- Input → decrypt → muestra secret en plaintext
- Auto-oculta 30s (opcionalmente: manual dismiss button)

**EntryCreateEditForm:**
- Toggle "Protect this entry?" 
- Si ON:
  - Si es primera vez → dialog de setup de contraseña maestra
  - Si ya existe → listo (solo toggle)
- Guarda con flags

**Master Password Setup Dialog:**
- "Set master password" input (password)
- "Confirm" input
- Botón "Set & Protect"
- Valida matching
- Genera salt, almacena hash

### 2.2 OUT-OF-SCOPE ❌

| Item | Razón |
|------|-------|
| ❌ Vault global con timeout | Innecesario; protect por entrada |
| ❌ flutter_secure_storage | No necesario; hash en BD es suficiente |
| ❌ Session timeout automático | Zero friction requerido |
| ❌ Biometría (huella, face) | Nice-to-have, Phase 2.1+ |
| ❌ Cambio de contraseña maestra | Phase 2.1 |
| ❌ Recovery password | Phase 3 |
| ❌ Cifrado de `content` | Solo `secret` |
| ❌ Sincronización | Phase 3 |
| ❌ Cifrado de metadata (tipo, tema) | Solo contenido sensible |

---

## 3. Approach & Rationale

### 3.1 Por Qué Este Enfoque (vs Vault Global)

| Aspecto | Vault Global (Old) | Per-Entry Protection (New) | Winner |
|--------|------------------|---------------------------|--------|
| **Friction** | Pregunta contraseña cada acceso | Pregunta solo si entry es protegida | ✅ New |
| **UX** | "¿Contraseña?" → búsqueda → "¿Contraseña?" | Búsqueda normal, [Reveal] si quiero | ✅ New |
| **Seguridad** | Todo cifrado desde start | Selectivo, user decide | ✅ Equal |
| **Performance** | Decrypt en startup (500-1000ms) | Decrypt on-demand (2-5ms) | ✅ New |
| **Scope** | Complejo (state management, timeout, etc.) | Simple (per-entry encrypt/decrypt) | ✅ New |
| **Simplicity** | 10+ providers, servicios complejos | 3 providers, 1 service | ✅ New |
| **Effort** | 85 horas (~2 weeks) | 20 horas (~1 week) | ✅ New |

### 3.2 Criptografía

**Elegido:**
- **AES-256-GCM** (Authenticated Encryption with Associated Data)
  - Simetría: Rápido
  - 256-bit key: Fuerte
  - GCM: Autenticación incluida (previene tampering)

- **Argon2id** (Key Derivation)
  - Password → 256-bit key
  - Parámetros: `t=2, m=65536, p=1` (rápido, suficientemente fuerte)
  - Salt: 16 bytes random, hex encoded

- **Nonce (IV):** 
  - 12 bytes random por cada cifrado (AES-GCM estándar)
  - NO reutilizable (garantizar uniqueness)

### 3.3 Almacenamiento

**Contraseña Maestra:**
```
master_password_config {
  password_hash_argon2: "9c...", // NO es la clave, solo hash
  salt_hex: "a1b2c3d4..."         // 16 bytes
}
```

**Entry Cifrada:**
```
Entry {
  requiresAuth: true,
  secret: "MySecretPassword",     // ORIGINAL (cuando descifrada)
  encrypted_secret: "K9lP...",    // CIFRADO en BD
  cipher_nonce: "n1n2n3...",      // 12 bytes hex
  cipher_tag: "t1t2t3..."         // GCM tag (16 bytes hex)
}
```

**Clave en Memoria (Durante Sesión):**
```
masterPasswordProvider {
  derivedKey: Uint8List(32)  // AES-256 key, volatile
}
```

---

## 4. Arquitectura (Diagramas Mínimos)

### 4.1 Data Flow: Create Protected Entry

```
User → CreateEntryForm
         ↓
    Toggle ON "Protect"?
         ↓
    [First time?]
    ├─ YES → MasterPasswordSetupDialog
    │        ↓ Password + Confirm
    │        ↓ generateSalt()
    │        ↓ hashPassword(salt) → master_password_config
    │        ↓ deriveMasterKey(password, salt) → RAM
    │
    └─ NO → deriveMasterKey(password, salt) [from stored salt] → RAM
         ↓
    Save entry (requiresAuth=true)
         ↓
    EntryAuthService.encrypt(plaintext, derivedKey)
         → {encryptedSecret, nonce, tag}
         ↓
    Insert into entries:
    {secret: null, encrypted_secret: "...", 
     cipher_nonce: "...", cipher_tag: "..."}
         ↓
    entryAuthServiceProvider.clearMasterPassword() [optional]
         ↓
    ✅ Entry guardada cifrada
```

### 4.2 Data Flow: View Protected Entry

```
User → EntryDetailView (requiresAuth=true)
         ↓
    [Reveal Secret] button
         ↓
    RevealSecretSheet (bottom modal)
         ├─ Password input
         ├─ "Unlock" button
         ↓
    EntryAuthService.decrypt(
      encryptedSecret, nonce, tag, derivedKey
    )
         ├─ Verify GCM tag
         ├─ AES-256 decrypt
         ↓ plaintext: "MyPassword"
         ↓
    Show plaintext in UI (30s auto-hide)
         ↓
    clearDerivation() after 30s
         ↓
    ✅ Secret visible, then obfuscated
```

### 4.3 Dependency Injection (Riverpod)

```
entryAuthServiceProvider
  ↓ (creates)
  EntryAuthService

masterPasswordProvider (StateNotifier)
  ├─ derivedKey: Uint8List?
  ├─ methods: setMasterPassword, clearMasterPassword
  ↓ (consumed by)
  EntryDetailView, CreateEntryForm

unlockedEntriesProvider (StateNotifier) [optional]
  ├─ Set<String> unlockedIds
  ├─ Auto-clear 30s per entry
```

### 4.4 Database Schema v1 → v2

```
BEFORE (v1):
entries {
  id, topic_key, type, title, secret (plaintext), content, ...
}

AFTER (v2):
entries {
  id, topic_key, type, title, secret (NULL if encrypted), 
  content, requires_auth (bool), encrypted_secret, 
  cipher_nonce, cipher_tag, ...
}

master_password_config {
  id, password_hash_argon2, salt_hex, created_at, updated_at
}

Migration:
- Add 4 columns to entries (default values: false, null, null, null)
- Create master_password_config empty
- NO data modification (selective encryption only on user action)
```

---

## 5. Implementación Detallada (Servicio)

### 5.1 EntryAuthService (Código-like Pseudocódigo)

```dart
class EntryAuthService {
  static const _saltLength = 16;  // bytes
  static const _nonceLength = 12; // AES-GCM standard
  static const _tagLength = 16;   // GCM tag

  // Derivar master key de password + salt
  Future<Uint8List> deriveMasterKey(
    String password, 
    String saltHex,
  ) async {
    final salt = hex.decode(saltHex);
    // Argon2id(password, salt, t=2, m=65536, p=1)
    final key = await Argon2id(
      password: utf8.encode(password),
      salt: salt,
      parallelism: 1,
      memorySize: 65536,
      iterations: 2,
      hashLength: 32,
    ).call();
    return key;
  }

  // Generar salt aleatorio
  String generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(
      _saltLength, 
      (_) => random.nextInt(256)
    );
    return hex.encode(saltBytes);
  }

  // Hash para verificación de password
  String hashPassword(String password, String saltHex) async {
    final key = await deriveMasterKey(password, saltHex);
    // Retornar como hex (para verificación posterior)
    return hex.encode(key);
  }

  // Encriptar 1 secret
  EncryptionResult encrypt(
    String plaintext,
    Uint8List derivedKey, // 32 bytes
  ) {
    final random = Random.secure();
    final nonce = List<int>.generate(
      _nonceLength, 
      (_) => random.nextInt(256)
    );

    final aes = AES(derivedKey, mode: GCMMode);
    final encrypted = aes.encrypt(
      utf8.encode(plaintext),
      iv: nonce,
    );

    // encrypted.bytes = ciphertext + tag
    final ciphertext = encrypted.bytes.sublist(
      0, 
      encrypted.bytes.length - _tagLength
    );
    final tag = encrypted.bytes.sublist(
      encrypted.bytes.length - _tagLength
    );

    return EncryptionResult(
      encryptedSecret: hex.encode(ciphertext),
      nonce: hex.encode(nonce),
      tag: hex.encode(tag),
    );
  }

  // Descifrar 1 secret
  String decrypt(
    String encryptedSecretHex,
    String nonceHex,
    String tagHex,
    Uint8List derivedKey,
  ) {
    final ciphertext = hex.decode(encryptedSecretHex);
    final nonce = hex.decode(nonceHex);
    final tag = hex.decode(tagHex);

    // AES-256-GCM
    final aes = AES(derivedKey, mode: GCMMode);
    final decrypted = aes.decrypt(
      ciphertext + tag,
      iv: nonce,
    );

    return utf8.decode(decrypted);
  }
}

class EncryptionResult {
  final String encryptedSecret;
  final String nonce;
  final String tag;
}
```

### 5.2 Riverpod Providers

```dart
// 1. EntryAuthService singleton
final entryAuthServiceProvider = Provider((_) => EntryAuthService());

// 2. Master password (derived key in memory)
final masterPasswordProvider = StateNotifierProvider<
  MasterPasswordNotifier, 
  Uint8List?
>((_) => MasterPasswordNotifier());

class MasterPasswordNotifier extends StateNotifier<Uint8List?> {
  MasterPasswordNotifier() : super(null);

  Future<void> setMasterPassword(String password) async {
    final config = await getMasterPasswordConfig();
    if (config == null) return; // Should not happen

    final derivedKey = await EntryAuthService().deriveMasterKey(
      password, 
      config.saltHex,
    );
    state = derivedKey;
  }

  void clearMasterPassword() {
    state = null;
  }

  bool isMasterPasswordSet() => state != null;
}

// 3. Unlocked entries (optional, for UI hint)
final unlockedEntriesProvider = StateNotifierProvider<
  UnlockedEntriesNotifier, 
  Set<String>
>((_) => UnlockedEntriesNotifier());

class UnlockedEntriesNotifier extends StateNotifier<Set<String>> {
  UnlockedEntriesNotifier() : super({});

  void markUnlocked(String entryId) {
    state = {...state, entryId};
    // Auto-clear after 30s
    Future.delayed(Duration(seconds: 30), () {
      state = state..remove(entryId);
    });
  }
}
```

---

## 6. Testing Strategy (Mínima)

**Objetivo:** 40-50 unit/integration tests, < 20 horas (parte de implementación)

### 6.1 Unit Tests (EntryAuthService)

1. ✅ `test_generateSalt_returns_16_bytes`
2. ✅ `test_deriveMasterKey_consistent`
3. ✅ `test_encrypt_returns_valid_result`
4. ✅ `test_decrypt_returns_plaintext`
5. ✅ `test_encrypt_decrypt_roundtrip`
6. ✅ `test_different_nonce_each_encrypt`
7. ✅ `test_decrypt_wrong_key_throws`
8. ✅ `test_decrypt_tampered_tag_throws`
9. ✅ `test_encrypt_large_secret`
10. ✅ `test_decrypt_unicode_secret`

### 6.2 Integration Tests (Entry + Encryption)

11. ✅ `test_create_protected_entry_stores_encrypted`
12. ✅ `test_view_protected_entry_decrypts_correctly`
13. ✅ `test_unprotected_entry_not_encrypted`
14. ✅ `test_edit_protected_entry_re_encrypts`
15. ✅ `test_search_returns_protected_entries` (FTS5)
16. ✅ `test_protected_entry_shows_locked_indicator`

### 6.3 Provider Tests (Riverpod)

17. ✅ `test_masterPasswordProvider_setMasterPassword`
18. ✅ `test_masterPasswordProvider_clearMasterPassword`
19. ✅ `test_masterPasswordProvider_isMasterPasswordSet`
20. ✅ `test_unlockedEntriesProvider_markUnlocked`
21. ✅ `test_unlockedEntriesProvider_autoClear30s`

### 6.4 UI Tests (Widget)

22. ✅ `test_entryDetailView_shows_reveal_button_if_protected`
23. ✅ `test_entryDetailView_reveal_button_opens_sheet`
24. ✅ `test_revealSecretSheet_password_input`
25. ✅ `test_revealSecretSheet_decrypt_on_unlock`
26. ✅ `test_revealSecretSheet_autohide_30s`
27. ✅ `test_createEntryForm_protect_toggle`
28. ✅ `test_masterPasswordSetupDialog_first_time`
29. ✅ `test_masterPasswordSetupDialog_password_mismatch_error`

### 6.5 Security Tests

30. ✅ `test_nonce_uniqueness_100_encrypts`
31. ✅ `test_gcm_tag_prevents_tampering`
32. ✅ `test_masterkey_not_logged`
33. ✅ `test_plaintext_not_logged_during_encrypt_decrypt`

### 6.6 Migration Tests (BD)

34. ✅ `test_migration_v1_to_v2_adds_columns`
35. ✅ `test_migration_v1_to_v2_preserves_existing_data`
36. ✅ `test_master_password_config_table_created`

**Total: ~36 tests, fácilmente extensible a 50 (E2E, edge cases, etc.)**

---

## 7. Dependencias (MÍNIMAS)

```yaml
dependencies:
  # Existing
  flutter:
  riverpod: ^2.4.0
  drift: ^2.13.0
  go_router: ^10.2.0

  # NEW for Phase 2
  cryptography: ^2.7.0      # AES-GCM, Argon2id, random
  pointycastle: ^3.10.0    # Backup crypto primitives (optional)

dev_dependencies:
  # Existing
  flutter_test:
  test: ^1.24.0
  
  # Optional (for testing)
  mockito: ^5.4.0
```

**Total nuevas dependencias: 2**

---

## 8. Timeline & Effort

### Estimación: ~20 Horas (1 Semana, 1 Persona @ 40h/week)

| Componente | Horas | Notas |
|-----------|-------|-------|
| EntryAuthService implementation + tests | 6h | Encrypt/decrypt/derive |
| Riverpod Providers setup | 2h | 3 providers |
| Database schema migration (Drift) | 2h | Simple ALTER + CREATE |
| EntryDetailView ([Reveal] button) | 3h | UI, decrypt flow |
| CreateEntryForm (protect toggle) | 2h | Toggle, setup dialog |
| MasterPasswordSetupDialog | 2h | Setup UX |
| Integration tests + E2E | 2h | 10-15 tests |
| Documentation + README | 1h | Security notes |
| **TOTAL** | **~20h** | **1 week** |

### Timeline Realista

**Sprint 1 (Días 1-2):**
- EntryAuthService + unit tests
- Riverpod providers
- Database migration

**Sprint 2 (Días 3-4):**
- UI: EntryDetailView, RevealSecretSheet
- UI: CreateEntryForm, MasterPasswordSetupDialog

**Sprint 3 (Día 5):**
- Integration tests
- Documentation
- Internal testing

**Sprint 4 (Preparación):**
- QA, fixes, ready for approval

---

## 9. Riesgos y Mitigación

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|--------|-----------|
| **Argon2id performance** | Baja | Bajo | Parámetros `t=2` (200ms en promedio, acceptable) |
| **Nonce reuse** | Muy baja | Crítico | Usar `Random.secure()`, verificar en tests |
| **GCM tag verification** | Muy baja | Crítico | Usar library estándar (`cryptography`), no custom |
| **Encrypted secret corruption** | Baja | Medio | Checksum visual en DB (nonce + tag hex validation) |
| **Master password forgotten** | Media | Crítico | No hay recovery (por diseño, Phase 2.1) |
| **Database migration fail** | Muy baja | Crítico | Test exhaustivamente, pero NO hay backup (no necesario, es append-only) |

**Conclusión:** Riesgos son MÍNIMOS y bien mitigados.

---

## 10. Comparativa: Vault Global vs Per-Entry

### Old Proposal (Vault Global)
```
Pros:
✅ Toda credencial cifrada desde inicio

Cons:
❌ Timeout global (15 min) → fricción
❌ Vault state complexity (5+ providers)
❌ Biometría mandatory (nice-to-have)
❌ Session management overhead
❌ Esfuerzo: 85 horas
❌ Risk: MEDIUM (migration complexity, timeout UX, vault state)
```

### New Proposal (Per-Entry Protection)
```
Pros:
✅ Zero friction para non-protected entries
✅ User decide qué proteger (granular)
✅ Simple (1 service, 3 providers)
✅ Fast (encrypt on-demand, no startup delay)
✅ Esfuerzo: 20 horas
✅ Risk: LOW (minimal state, no timeout, no vault)
✅ Aligned con Taúl philosophy (minimalista)

Cons:
❌ Require manual protection (user must toggle)
❌ No offline password change (Phase 2.1)
```

**Conclusión:** NEW es 4x más simple, 4x más rápido, user-centric.

---

## 11. Architecture Decisions (ADR)

### ADR-1: Per-Entry vs Vault Global

**Status:** ✅ **DECIDED** (Per-Entry)

**Decision:**
- Protección por entrada (`requiresAuth` boolean)
- Una contraseña maestra global para todas
- Sin state management de vault

**Rationale:**
1. Zero friction UX (users no forced to auth for every access)
2. Granular control (choose what to protect)
3. Minimal infrastructure (no vault, no timeout, no session)
4. 4x faster to implement (20h vs 85h)
5. Aligned with Taúl philosophy (minimalista, rápido)

---

### ADR-2: AES-256-GCM vs Other Ciphers

**Status:** ✅ **DECIDED** (AES-256-GCM)

**Decision:**
- Use AES-256-GCM for all encryptions

**Rationale:**
1. Industry standard for AEAD (Authenticated Encryption)
2. Fast (hardware acceleration on modern phones)
3. No known attacks
4. GCM tag prevents tampering (better than CBC)

---

### ADR-3: Master Password Storage

**Status:** ✅ **DECIDED** (Hash in SQLite, no SecureStorage)

**Decision:**
- Store `master_password_hash` (Argon2id) in SQLite
- Derived key in memory only (Riverpod state)
- NO flutter_secure_storage

**Rationale:**
1. Simplify dependencies (no platform-specific code)
2. Hash is OK to store (not the password itself)
3. Derived key in memory is volatile (cleared on exit)
4. Reduced attack surface

---

### ADR-4: No Session Timeout

**Status:** ✅ **DECIDED** (No Timeout)

**Decision:**
- No automatic session timeout
- Derived key stays in memory until app exit
- Optional: User can manually clear

**Rationale:**
1. Zero friction UX
2. User controls own security
3. Derived key cleared on app exit anyway
4. Session timeout adds complexity without user benefit

---

## 12. Success Criteria (Acceptance)

### Functional

- [ ] User can create entry with `requiresAuth=true`
- [ ] First protection prompts master password setup
- [ ] Master password is stored as Argon2id hash
- [ ] EntryDetailView shows [Reveal Secret] button if protected
- [ ] Click [Reveal] → password input → decrypt → show secret
- [ ] Secret auto-hides after 30 seconds
- [ ] Unprotected entries work normally (no change)
- [ ] All entry types can be protected
- [ ] Search returns protected entries with 🔒 indicator
- [ ] FTS5 still < 200 ms (no degradation)

### Non-Functional

- [ ] AES-256-GCM with proper GCM tag
- [ ] Argon2id(t=2, m=65536, p=1)
- [ ] Nonce uniqueness (Random.secure)
- [ ] No plaintext secrets in logs
- [ ] Master password never logged
- [ ] Test coverage ≥ 80%
- [ ] Critical paths (encrypt/decrypt) 100% coverage

---

## 13. Documentación

### Entregables

1. ✅ **PHASE_2_PROPOSAL_v2_SIMPLIFIED.md** (este documento)
2. ✅ **EntryAuthService.dart** (implementation + inline docs)
3. ✅ **Riverpod Providers** (masterPasswordProvider, etc.)
4. ✅ **Database Migration** (Drift script v1→v2)
5. ✅ **Unit Tests** (EntryAuthService, 10+ tests)
6. ✅ **Integration Tests** (Entry encryption flow)
7. ✅ **Widget Tests** (UI screens)
8. ✅ **SECURITY.md** (Best practices, threat model)
9. ✅ **README update** (Quick start protection)

### Security Documentation (SECURITY.md)

```markdown
# Taúl Security — Phase 2

## Encryption

- AES-256-GCM (AEAD, authenticated)
- Nonce: 12 bytes random (per encryption)
- Tag: 16 bytes (GCM authentication)

## Key Derivation

- Argon2id(t=2, m=65536, p=1)
- Salt: 16 bytes random, stored in master_password_config
- Key: 256 bits (32 bytes)

## Storage

- Master password NEVER stored (only hash)
- Derived key: in memory only, cleared on exit
- Encrypted secrets: stored in entries table

## Threats Mitigated

1. **Plaintext credential theft** → AES-256-GCM
2. **Rainbow table attack** → Argon2id + random salt
3. **Tampering with ciphertext** → GCM tag verification
4. **Nonce reuse** → Random.secure() per encryption
5. **Derived key extraction** → Volatile memory, cleared on exit

## Threats NOT Mitigated (Out of Scope)

- Physical device access after unlock (user's responsibility)
- Master password brute force (offline, but Argon2id makes it slow)
- Timing attacks (possible on password verification, negligible in practice)
- Master password recovery (by design, Phase 2.1)
```

---

## 14. Next Steps (Si es Aprobada)

### Inmediatamente (Día 0)

1. ✅ Aprobación de esta propuesta (sign-off)
2. ✅ Crear Jira tasks (1 per component)
3. ✅ Assign developer

### Paralelo (Días 0-2)

1. **sdd-spec:** Escribir requisitos detallados
   - EntryAuthService specification
   - Riverpod providers contract
   - Database schema detailed

2. **sdd-design:** Diagramas, security review
   - Architecture diagrams
   - Data flow diagrams
   - Security threat model

### Implementation (Días 3-10)

- Follow timeline (Sprint 1-4)
- Daily check-ins
- QA reviews per component

### Final (Día 11+)

- Merge to main
- Release notes
- User documentation

---

## 15. Conclusión

**Taúl Phase 2 (v2)** es una propuesta **SIMPLIFICADA, USER-CENTRIC, y REALISTA**:

✅ **User-Centric:** User decide qué proteger (zero friction)  
✅ **Simple:** 1 service, 3 providers, 20 horas  
✅ **Secure:** AES-256-GCM + Argon2id  
✅ **Fast:** No degradation (FTS5 intacto)  
✅ **Maintainable:** Minimal infrastructure, clean architecture  
✅ **Low Risk:** Riesgos mínimos y bien mitigados  

**Estimación: 🟢 LOW (20 horas, ~1 semana)**

**Recomendación:** ✅ **APROBAR** y proceder con sdd-spec + sdd-design en paralelo.

---

## Aprobación

**Propuesta:** `sdd/phase-2-entry-protection-optional/proposal`  
**Versión:** 2.1 (Simplified)  
**Estado:** 🟡 Pendiente Aprobación  
**Responsable:** Equipo de Arquitectura  

### Sign-Off

| Role | Name | Email | Status | Date | Signature |
|------|------|-------|--------|------|-----------|
| **Tech Lead** | __________ | __________ | ☐ | ______ | ✓ / ✗ |
| **Product Owner** | __________ | __________ | ☐ | ______ | ✓ / ✗ |
| **Architect** | __________ | __________ | ☐ | ______ | ✓ / ✗ |
| **Security** | __________ | __________ | ☐ | ______ | ✓ / ✗ |

---

**Documento:** `PHASE_2_PROPOSAL_v2_SIMPLIFIED.md`  
**Fecha:** 2025  
**Mantenido por:** Architecture Team  
