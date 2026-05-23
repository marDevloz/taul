# Propuesta SDD – Fase 2: Cifrado, Vault Seguro, Desbloqueo Biométrico

**Taúl — Sistema de Almacenamiento Personal Minimalista, Rápido y Seguro**

**Versión:** 2.0-Phase2-Proposal  
**Fecha:** 2025  
**Estado:** 🟡 Propuesta — Pendiente Aprobación  
**Responsable:** Equipo de Arquitectura  

---

## 1. Contexto Ejecutivo

### 1.1 Estado Actual (Fase 1)

La Fase 1 ha completado exitosamente:
- ✅ CRUD completo de entradas
- ✅ Búsqueda instantánea con SQLite FTS5
- ✅ Stack funcional: Flutter + Riverpod + Drift + go_router
- ✅ Arquitectura limpia y domain-driven
- ✅ Modelo de dominio estable (Entry, tipos, topic_key)

**Dependencias tecnológicas validadas:**
- Flutter (multiplataforma)
- Riverpod (state management)
- Drift (database ORM + migrations)
- go_router (navegación)

---

## 2. Intent (Problema, Por Qué Ahora, Qué Éxito)

### 2.1 Problema

Taúl almacena credenciales y secretos personales. Actualmente **sin cifrado ni autenticación biométrica**, esto representa:

1. **Riesgo de seguridad crítico:** El campo `secret` está almacenado en texto plano en SQLite.
2. **Vulnerabilidad a acceso local:** Un atacante con acceso físico o al archivo `.db` puede leer todas las credenciales.
3. **Falta de aislamiento de sesión:** Una sesión abierta expone todos los datos sin límite de tiempo.
4. **Ausencia de autenticación rápida:** No hay desbloqueo biométrico; el acceso es manual y sin límite temporal.

### 2.2 Por Qué Ahora

- **Fase 1 es estable:** La base de datos, el CRUD y la búsqueda funcionan correctamente.
- **Requisito no funcional 7.2 (Seguridad):** El SDD v2 ya especifica AES-256-GCM + Argon2id.
- **Preparación para Fase 3:** La sincronización manual requiere que los datos sensibles estén cifrados.
- **Confianza del usuario:** Sin cifrado, Taúl no puede posicionarse como "almacén seguro".

### 2.3 Definición de Éxito

**La Fase 2 se considera exitosa cuando:**

1. ✅ El campo `secret` está cifrado con AES-256-GCM en todas las credenciales nuevas y migradas.
2. ✅ La clave maestra se deriva con Argon2id y se almacena de forma segura en flutter_secure_storage.
3. ✅ El usuario puede desbloquear el vault mediante biométricos (huella, cara).
4. ✅ La sesión se cierra automáticamente tras 15 minutos de inactividad.
5. ✅ La migración v1 → v2 es automática y reversible (backup).
6. ✅ El rendimiento no se degrada significativamente (búsqueda < 200 ms).
7. ✅ Todas las capas de cripto y biométricos están testeadas y abstraídas.

---

## 3. Scope Detallado

### 3.1 IN-SCOPE (Incluido en Fase 2)

#### 3.1.1 Cifrado de Secretos
- **AES-256-GCM** para el campo `secret` en todas las credenciales
- **NO se cifra `content`** (solo `secret`)
- Las entradas sin `secret` no son modificadas
- Nonce (IV) aleatorio por cada cifrado
- Autenticación de ciphertext mediante tag GCM

#### 3.1.2 Gestión de Clave Maestra
- **Derivación de clave:** Argon2id(password, salt, t=3, m=65536, p=4)
- **Almacenamiento seguro:** flutter_secure_storage (Android Keystore, iOS Keychain)
- **Salt aleatorio:** 16 bytes generados con crypto.Random()
- **Versionado de parámetros:** Campo `crypto_version` en DB para futuros cambios (v1, v2, ...)

#### 3.1.3 Autenticación Biométrica (Desbloqueo Rápido)
- **Local Auth:** Habilitar desbloqueo mediante huella digital o reconocimiento facial
- **Opcional por usuario:** No es obligatorio, solo un atajo
- **Sin almacenamiento de biométricos:** Se validan localmente mediante local_auth
- **Token de sesión efímero:** Un token JWT local generado tras desbloqueo exitoso

#### 3.1.4 Gestión de Sesiones
- **Cierre automático:** Tras 15 minutos sin actividad
- **Cierre manual:** Botón de logout en la interfaz
- **Renovación de sesión:** Cualquier interacción reinicia el contador
- **Almacenamiento de sesión:** Token en memoria + flutter_secure_storage

#### 3.1.5 Migración de Base de Datos
- **v1 → v2:** Automática al iniciar la aplicación
- **Backup pre-migración:** Generación obligatoria de `taul_backup_v1_<timestamp>.db.zst`
- **Reversibilidad:** El usuario puede restaurar la v1 desde el backup
- **Validación:** Checksum post-migración para garantizar integridad

#### 3.1.6 Nuevas Capas de Servicio

**CryptoService:**
- `encrypt(plaintext, masterKey) → (ciphertext, nonce, tag, version)`
- `decrypt(ciphertext, nonce, tag, masterKey) → plaintext`
- `deriveMasterKey(password, salt) → bytes`
- `generateSalt() → bytes`
- `validateNonce(nonce) → bool`

**BiometricService:**
- `isAvailable() → bool`
- `canAuthenticate() → bool`
- `authenticate(reason) → bool`
- `disableBiometric()`
- `enableBiometric()`
- `isBiometricEnabled() → bool`

**SecureStorageService:**
- `setMasterKey(key)`
- `getMasterKey() → bytes?`
- `deleteMasterKey()`
- `setSalt(salt)`
- `getSalt() → bytes?`
- `setSessionToken(token)`
- `getSessionToken() → String?`
- `deleteSessionToken()`

#### 3.1.7 Nuevas Vistas Mínimas

**UnlockScreen:**
- Campo de contraseña o botón de desbloqueo biométrico
- Indicador de error
- Link a "Olvidé mi contraseña" (abre menú de backup)
- Tema oscuro coherente con la app

**BiometricSettingsScreen:**
- Toggle para habilitar/deshabilitar desbloqueo biométrico
- Información sobre cómo funciona
- Botón de test

**SessionTimeoutDialog:**
- Aviso de cierre de sesión próximo (con 1 min de avance)
- Opción de renovar sesión o cerrar

#### 3.1.8 Base de Datos — Schema v2

```sql
-- Tabla entries (modificada)
CREATE TABLE entries (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  metadata TEXT,
  tags TEXT,
  topic_key TEXT,
  secret TEXT,  -- AHORA NULLABLE Y CODIFICADO EN BASE64
  secret_nonce TEXT,  -- NUEVO: Nonce del cifrado
  secret_tag TEXT,    -- NUEVO: Tag de autenticación GCM
  crypto_version INTEGER DEFAULT 1,  -- NUEVO: Versión de cripto
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  version INTEGER NOT NULL,
  FOREIGN KEY(topic_key) REFERENCES topics(key)
);

-- Tabla para parámetros criptográficos globales
CREATE TABLE crypto_config (
  id INTEGER PRIMARY KEY,
  salt_hex TEXT NOT NULL,  -- Salt en hexadecimal
  crypto_version INTEGER DEFAULT 1,
  master_key_hash TEXT,  -- SHA-256(master_key) para validación
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Tabla para sesiones (sesión actual)
CREATE TABLE sessions (
  id TEXT PRIMARY KEY,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  is_active BOOLEAN DEFAULT 1
);
```

#### 3.1.9 Nuevos Providers Riverpod (5 totales)

1. **cryptoServiceProvider:** Instancia única de CryptoService
2. **biometricServiceProvider:** Instancia única de BiometricService
3. **secureStorageServiceProvider:** Instancia única de SecureStorageService
4. **masterKeyProvider:** StateNotifier — Clave maestra en memoria (volatile)
5. **sessionProvider:** StateNotifier — Estado de sesión actual (token, expiración, activo)

#### 3.1.10 Cambios en DAOs y Repositories

**EntryRepository:**
- `createWithSecret(entry, masterKey)` — Cifra secret antes de insertar
- `getDecrypted(id, masterKey)` — Descifra secret al leer
- `updateSecret(id, newSecret, masterKey)` — Re-cifra secret
- `searchIgnoringSecret()` — Búsqueda FTS5 sin tocar secretos

**No se modifica FTS5:**
- El índice sigue siendo solo sobre title, content, tags
- `secret` nunca se indexa

#### 3.1.11 Manejo de Errores

- **CryptoException:** Fallos en cifrado/descifrado
- **BiometricException:** Fallos en autenticación biométrica
- **SecureStorageException:** Fallos en flutter_secure_storage
- **SessionExpiredException:** Sesión expirada, requiere re-unlock
- **MigrationException:** Fallos en migración v1 → v2

#### 3.1.12 Librerías Nuevas

```yaml
dependencies:
  cryptography: ^2.1.0  # Cifrado AES-256-GCM
  flutter_secure_storage: ^9.0.0  # Almacenamiento seguro
  local_auth: ^2.1.0  # Desbloqueo biométrico
  pointycastle: ^3.7.0  # Complemento para Argon2id
```

---

### 3.2 OUT-OF-SCOPE (NO incluido en Fase 2)

❌ **NO:** Cifrado de `content` (solo `secret`)  
❌ **NO:** Sincronización de Fase 3 (se implementa en Phase 3)  
❌ **NO:** UI avanzada (solo vistas mínimas)  
❌ **NO:** Recuperación de contraseña por email/cloud (offline-first)  
❌ **NO:** Multi-usuario o perfiles  
❌ **NO:** Auditoría de acceso (logs de quién leyó qué)  
❌ **NO:** Cifrado de metadatos (solo secret)  
❌ **NO:** Certificados TLS (la sincronización es local, se implementará en Phase 3)  
❌ **NO:** Cambio de contraseña maestra (se planifica para Phase 2.1 o 3)  

---

## 4. Approach (Estrategia de Implementación)

### 4.1 Selección de Approach: **Approach B** (Cifrado Selectivo)

**Justificación (basada en exploración Fase 1):**

| Aspecto | Approach A (Todo Cifrado) | Approach B (Solo Secret) | Seleccionado |
|--------|--------------------------|--------------------------|------------|
| Rendimiento Búsqueda | Bajo (descifra FTS5) | Alto (FTS5 sin descifrado) | ✅ B |
| Complejidad | Alto | Bajo | ✅ B |
| Cobertura de Seguridad | Máxima | Suficiente para credenciales | ✅ B |
| Tiempo de Implementación | 8 sem | 4 sem | ✅ B |
| Mantenibilidad | Compleja | Simple | ✅ B |

**Por qué Approach B:**

1. **Seguridad donde importa:** Las credenciales (secret) son el activo más valioso.
2. **FTS5 sin overhead:** La búsqueda sigue siendo rápida (< 200 ms) porque no requiere descifrado.
3. **Escalabilidad:** Con 10.000+ entradas, descifrar todo sería prohibitivo.
4. **Simplicidad:** Menos puntos de fallo, menos validación, más fácil de auditar.
5. **Offline-first:** No requiere conexión para descifrado.

---

### 4.2 Flujo de Implementación (Arquitectura)

```
┌─────────────────────────────────────────────────────────────┐
│                    INTERFAZ DE USUARIO                       │
├─────────────────────────────────────────────────────────────┤
│  UnlockScreen │ MainSearchScreen │ EntryDetailScreen │ ...   │
└────────┬───────────────────────────────────────────────┬─────┘
         │                                               │
    ┌────▼───────────────────────────────────────────────▼─────┐
    │              RIVERPOD STATE MANAGEMENT                    │
    ├──────────────────────────────────────────────────────────┤
    │ masterKeyProvider │ sessionProvider │ currentEntryProvider│
    └────┬───────────────────────────────────────────────────┬──┘
         │                                                   │
    ┌────▼──────────────────────────────────────────────────▼──┐
    │          DOMAIN LAYER (UseCases, Repositories)           │
    ├──────────────────────────────────────────────────────────┤
    │ GetEntryUseCase (con descifrado) │ SearchEntriesUseCase  │
    └────┬───────────────────────────────────────────────────┬──┘
         │                                                   │
    ┌────▼──────────────────────────────────────────────────▼──┐
    │        INFRASTRUCTURE LAYER (Services + DAOs)            │
    ├──────────────────────────────────────────────────────────┤
    │                                                           │
    │  ┌────────────────────┐  ┌─────────────────────────┐    │
    │  │  CryptoService     │  │  EntryRepository + DAO  │    │
    │  │ (AES-256-GCM +     │  │  (CRUD + buscar)        │    │
    │  │  Argon2id)         │  │                         │    │
    │  └────────────────────┘  └─────────────────────────┘    │
    │                                                           │
    │  ┌────────────────────┐  ┌─────────────────────────┐    │
    │  │BiometricService    │  │SecureStorageService    │    │
    │  │(local_auth)        │  │(flutter_secure_storage)│    │
    │  └────────────────────┘  └─────────────────────────┘    │
    │                                                           │
    └────┬───────────────────────────────────────────────────┬──┘
         │                                                   │
    ┌────▼──────────────────────────────────────────────────▼──┐
    │            DATA LAYER (Drift + SQLite FTS5)              │
    ├──────────────────────────────────────────────────────────┤
    │  entries (v2) │ crypto_config │ sessions │ fts5_index    │
    └──────────────────────────────────────────────────────────┘
```

### 4.3 Flujo de Inicio de Sesión

```
1. App inicia
   ↓
2. ¿Hay sesión válida en memoria?
   → SÍ: Ir a 5
   → NO: Ir a 3
   ↓
3. UnlockScreen (mostrar)
   ↓
4. Usuario elige:
   a) Biométrico (si habilitado)
      → authenticate(local_auth) → OK? → Generar token
   b) Contraseña
      → Pedir password
      → deriveMasterKey(password, salt)
      → Validar contra master_key_hash
   ↓
5. Cargar masterKey a memoria (masterKeyProvider)
   Cargar sessionToken (sessionProvider)
   ↓
6. Iniciar contador de inactividad (15 min)
   ↓
7. MainSearchScreen (ir)
```

### 4.4 Flujo de Descifrado de Entrada

```
Cuando el usuario abre una credencial:

1. Leer entry desde DB
   - secret (BASE64)
   - secret_nonce (HEX)
   - secret_tag (HEX)
   ↓
2. ¿Hay masterKey en memoria?
   → NO: SessionExpiredException → re-unlock
   ↓
3. decrypt(
     ciphertext=base64Decode(secret),
     nonce=hexDecode(secret_nonce),
     tag=hexDecode(secret_tag),
     masterKey=masterKeyProvider.read()
   ) → plaintext
   ↓
4. Mostrar plaintext en UI
   (nunca guardarlo en DB desprotegido)
```

### 4.5 Migración v1 → v2

```
Cuando el usuario abre la app por primera vez tras actualizar:

1. Detectar versión de DB actual
   ↓
2. Si v1:
   a) Generar backup: taul_backup_v1_<timestamp>.db.zst
   b) Mostrar "Setup de Seguridad"
   c) Pedir contraseña nueva (para Argon2id)
   d) Generar salt aleatorio
   e) Derivar masterKey
   f) Guardar crypto_config
   g) Re-cifrar todos los `secret` existentes
      - Para cada entry con secret != NULL:
        - cipher = encrypt(secret, masterKey)
        - UPDATE entry SET secret=..., secret_nonce=..., secret_tag=...
   h) Actualizar schema (añadir columnas, crear índices)
   i) Crear tabla crypto_config
   j) Crear tabla sessions
   ↓
3. Validar integridad (checksum de tablas)
   ↓
4. Ir a UnlockScreen para primer desbloqueo
```

---

## 5. Impacto Técnico Detallado

### 5.1 Cambios de Base de Datos

| Elemento | Cambio | Impacto |
|----------|--------|--------|
| Schema | +3 columnas (secret_nonce, secret_tag, crypto_version) | Bajo (backward compatible con padding) |
| Índices | Sin cambios en FTS5 | Ninguno |
| Tablas | +2 nuevas (crypto_config, sessions) | Bajo |
| Datos | Re-cifrado de secrets existentes | Medio (migración one-time) |
| Rendimiento | Sin degradación (búsqueda sigue igual) | Ninguno |

### 5.2 Cambios en Capas

| Capa | Cambio | Archivos | Esfuerzo |
|------|--------|----------|----------|
| Domain | +2 ValueObjects (EncryptedSecret, SessionToken) | 2 | Bajo |
| Infrastructure | +3 Services nuevos | 3 files (100 líneas c/u) | Bajo |
| Infrastructure | +Drift migration (v1 → v2) | migration.dart | Bajo |
| Infrastructure | DAOs actualización (métodos wrap de encriptación) | entry_dao.dart | Bajo |
| UI | +2 nuevas screens | 2 files (150 líneas c/u) | Bajo |
| Providers | +5 nuevos Riverpod providers | providers.dart | Bajo |
| Tests | +Test suite para cada service | 4 test files | Medio |

### 5.3 Dependencias Tecnológicas

```yaml
# Nuevas
cryptography: ^2.1.0         # AES-256-GCM
flutter_secure_storage: ^9.0.0  # Almacenamiento seguro
local_auth: ^2.1.0           # Biométricos
pointycastle: ^3.7.0         # Argon2id soporte

# Ya presentes (reutilizar)
riverpod: (ya en pubspec.yaml)
drift: (ya en pubspec.yaml)
go_router: (ya en pubspec.yaml)
```

### 5.4 Nuevas Rutas de Navegación (go_router)

```dart
GoRoute(
  path: '/unlock',
  name: 'unlock',
  builder: (context, state) => const UnlockScreen(),
),
GoRoute(
  path: '/biometric-settings',
  name: 'biometricSettings',
  builder: (context, state) => const BiometricSettingsScreen(),
),
```

---

## 6. Riesgos, Mitigaciones y Decisiones Abiertas

### 6.1 Riesgos Identificados

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|--------|-----------|
| **Pérdida de datos en migración** | Media | Crítico | Backup obligatorio pre-migración, test de reversibilidad |
| **Performance: Argon2id lento** | Baja | Medio | Usar parámetros moderados (t=3, m=65536, p=4), hacer async |
| **Timeout de sesión abrupto** | Media | Bajo | Dialog de aviso 1 min antes, autoguardado de borradores |
| **Fallos de biométricos en algunos dispositivos** | Media | Bajo | Fallback obligatorio a contraseña, no obligatorio |
| **Flutter_secure_storage no disponible** | Baja | Crítico | Fallback a preferences encriptadas (menos seguro, con warning) |
| **Nonce collision (AES-GCM)** | Muy Baja | Crítico | Usar crypto.Random() con verificación de uniqueness |
| **Backup incompatible entre versiones** | Baja | Medio | Versionado de backup format, test de compatibilidad |

### 6.2 Preguntas Abiertas

1. **¿Qué hacer si el usuario olvida su contraseña?**
   - **Opción A:** Pérdida total de datos (offline-first, seguro, pero drástico)
   - **Opción B:** Backup con recovery key (requiere interfaz de backup)
   - **Decisión:** Diferir a Phase 2.1, comenzar con Opción A

2. **¿Cifrar también el campo `metadata`?**
   - **Opción A:** Solo `secret` (actual scope)
   - **Opción B:** `secret` + `metadata` (más seguro, más lento)
   - **Decisión:** Solo `secret` (Approach B), revisable en Phase 3

3. **¿Deshabilitar la copia/pegado de secrets en el clipboard?**
   - **Opción A:** Permitir con timeout de borrado automático (UX mejor)
   - **Opción B:** Prohibir (UX peor, más seguro)
   - **Decisión:** Opción A, con timeout de 30 seg

4. **¿Cambio de contraseña maestra durante la sesión?**
   - **Opción A:** No disponible (simplificar Phase 2)
   - **Opción B:** Disponible con re-cifrado de todos los secrets
   - **Decisión:** Opción A, diferir a Phase 3

5. **¿Sincronización entre dispositivos pre-Phase 3?**
   - **Respuesta:** NO, pero el cifrado debe ser compatible con el protocolo de sincronización futuro de Phase 3

---

## 7. Estimación de Esfuerzo

### 7.1 Desglose por Componente

| Componente | Horas | Justificación |
|-----------|-------|--------------|
| **CryptoService** | 8 | AES-256-GCM, Argon2id, derivación |
| **BiometricService** | 4 | Wrapper sobre local_auth |
| **SecureStorageService** | 4 | Wrapper sobre flutter_secure_storage |
| **EntryRepository (cifrado/descifrado)** | 6 | Refactor de métodos de lectura/escritura |
| **Migration v1 → v2** | 8 | Drift migration, re-cifrado, validación |
| **UI: UnlockScreen** | 6 | Formulario + biométricos + errores |
| **UI: BiometricSettingsScreen** | 4 | Toggle + información + test |
| **UI: SessionTimeoutDialog** | 3 | Dialog simple |
| **Riverpod Providers** | 6 | 5 providers nuevos, validación |
| **Tests (unit + integration)** | 16 | CryptoService (8h), Migration (5h), Providers (3h) |
| **Documentación y revisión** | 5 | README de security, inline docs |
| **Integración y fixes** | 8 | Debugging, refactoring menor, edge cases |
| **Buffer (10%)** | 9 | Para problemas imprevistos |
| **TOTAL** | **85 horas** | ~2 semanas (si 1 person, 40h/sem) |

### 7.2 Criterio de Estimación: **MEDIO**

**Justificación:**
- ✅ Patrón de arquitectura ya establecido (Infrastructure layer)
- ✅ Dependencias claras y maduras (cryptography, local_auth, flutter_secure_storage)
- ✅ Scope bien definido (solo `secret`, no `content`)
- ✅ Migración es one-time (no required después)
- ⚠️ Criptografía debe ser correcta (zero tolerance para bugs)
- ⚠️ Migración v1 → v2 es crítica (requiere testing exhaustivo)
- ⚠️ Biométricos depende de APIs nativas

---

## 8. Timeline Propuesto

### 8.1 Hitos

| Hito | Duración | Dependencias | Criterios de Salida |
|------|----------|--------------|-------------------|
| **Sprint 1: Infraestructura Cripto** | 1.5 sem | Ninguna | CryptoService + Tests (100% coverage) |
| **Sprint 2: Almacenamiento Seguro** | 1 sem | Sprint 1 | SecureStorage + Biometric Services + Tests |
| **Sprint 3: Migración v1 → v2** | 1 sem | Sprint 1, 2 | Migration Drift + ValidaciónIntegridad |
| **Sprint 4: UI + Providers** | 1 sem | Sprint 2, 3 | UnlockScreen + Providers + navegación |
| **Sprint 5: Integración + Testing** | 1 sem | Sprint 4 | E2E tests, edge cases, documentación |
| **QA y Fixes** | 0.5 sem | Sprint 5 | All tests green, documentación final |
| **TOTAL** | ~5 semanas | — | Release Phase 2 |

---

## 9. Criterios de Aceptación

### 9.1 Funcional

- [ ] Un usuario nuevo puede crear una contraseña maestra al iniciar la app
- [ ] Las credenciales con `secret` se cifran correctamente (verificable con DB dump)
- [ ] Un usuario puede desbloquear el vault con contraseña
- [ ] Un usuario puede desbloquear el vault con biométricos (si está habilitado)
- [ ] La sesión se cierra automáticamente tras 15 min de inactividad
- [ ] El usuario recibe aviso 1 min antes del cierre automático
- [ ] Las entradas cifradas se descifran correctamente al abrirlas
- [ ] La búsqueda FTS5 sigue funcionando sin degradación (< 200 ms)
- [ ] La migración v1 → v2 es automática y reversible
- [ ] El backup pre-migración se crea y puede restaurarse

### 9.2 No Funcional

- [ ] Criptografía: AES-256-GCM con autenticación
- [ ] Derivación: Argon2id(t=3, m=65536, p=4)
- [ ] Rendimiento: Búsqueda < 200 ms con 10k entradas
- [ ] Seguridad: Masterkey nunca sale de flutter_secure_storage
- [ ] Seguridad: Session token es efímero (volatile)
- [ ] Testabilidad: 85%+ coverage en servicios criptográficos
- [ ] Testabilidad: Migration testeable y reversible

### 9.3 Calidad de Código

- [ ] Cero warnings en análisis estático
- [ ] Documentación inline en servicios criptográficos
- [ ] Error handling exhaustivo con custom exceptions
- [ ] Logging sin datos sensibles
- [ ] Padding correcto en todos los valores cifrados

---

## 10. Decisiones Arquitectónicas

### ADR-001: Cifrado Selectivo (Solo Secret)

**Status:** Aceptado (Approach B)  
**Contexto:** Balancear seguridad vs. performance  
**Decisión:** Cifrar solo el campo `secret`, no `content`  
**Razones:**
- Performance: FTS5 sin overhead
- Seguridad: Credenciales están protegidas
- Simplicidad: Menos puntos de fallo
- Escalabilidad: 10k+ entradas sin degradación

**Consecuencias:**
- El contenido visible en la búsqueda (si se le pide a un atacante que busque palabras clave)
- Pero secretos están siempre protegidos

---

### ADR-002: flutter_secure_storage para Masterkey

**Status:** Aceptado  
**Contexto:** Almacenamiento seguro de clave maestra  
**Decisión:** Usar flutter_secure_storage (Android Keystore, iOS Keychain)  
**Razones:**
- Standard de industria para Flutter
- Hardware-backed encryption (si disponible)
- Aislamiento por app
- No requiere SDK externo

**Consecuencias:**
- Dependencia en SDKs nativos (mínima)
- Algunos dispositivos antiguos pueden no tener Keystore

---

### ADR-003: Sesión Efímera en Memoria

**Status:** Aceptado  
**Contexto:** Mantener clave maestra accesible durante la sesión  
**Decisión:** Masterkey en memoria (Riverpod StateNotifier), volátil  
**Razones:**
- Offline-first
- Rápida
- Fácil de vaciar
- Clear separation of concerns

**Consecuencias:**
- Si la app es killada, la sesión se pierde (es lo deseado)
- Requiere que el usuario se vuelva a autenticar

---

### ADR-004: Timeout de 15 minutos

**Status:** Aceptado  
**Contexto:** Balance entre conveniencia y seguridad  
**Decisión:** Cierre automático de sesión tras 15 min de inactividad  
**Razones:**
- No demasiado corto (< 5 min sería molesto)
- No demasiado largo (> 30 min sería inseguro)
- Standard en aplicaciones bancarias

**Consecuencias:**
- Usuario debe autenticarse nuevamente si la app está inactiva

---

## 11. Dependencias Externas

### 11.1 Dependencias Funcionales

- ✅ Drift (ya presente): Migración v1 → v2
- ✅ Riverpod (ya presente): State management
- ✅ Flutter (ya presente): UI
- ⚠️ cryptography: Nueva (v2.1.0+)
- ⚠️ flutter_secure_storage: Nueva (v9.0.0+)
- ⚠️ local_auth: Nueva (v2.1.0+)

### 11.2 Dependencias en Fase 3

- Sincronización requiere que los secrets estén cifrados (esta Fase 2 prepara el terreno)
- El protocolo de sincronización debe ser compatible con AES-256-GCM

---

## 12. Compatibilidad y Rollback

### 12.1 Rollback Plan

Si la Fase 2 falla en producción:

1. **Detección:** Tests de humo fallan tras actualización
2. **Decision Point:** ¿Rollback o hotfix?
3. **Rollback:**
   - Revertir APK/IPA a v1
   - Usuario restaura DB desde backup (taul_backup_v1_<timestamp>.db.zst)
   - Todos los datos intactos
4. **Hotfix (si menor):**
   - Patch release (v2.0.1)
   - Corrección de bug
   - Re-deploying

### 12.2 Compatibilidad Forward

- Futuras versiones (Phase 3, 4) pueden leer DBs de Phase 2
- Campo `crypto_version` permite evolución sin reescrituras

---

## 13. Matriz de Decisiones Pendientes

| Pregunta | Opción A | Opción B | Status | Decidido Por |
|----------|----------|----------|--------|--------------|
| ¿Cifrar metadata? | No (scope actual) | Sí (más seguro) | Abierto | Phase 2 Review |
| ¿Password recovery? | Pérdida total | Recovery key | Diferido | Phase 2.1+ |
| ¿Change password?| No en Phase 2 | Sí (con re-cifrado) | No incluir | Phase 3 |
| ¿Clipboard timeout?| 30 seg | 60 seg | Abierto | UX Review |
| ¿Biometric obligatorio?| Opcional | Obligatorio | Opcional | User Research |

---

## 14. Definición de "Done"

La Fase 2 está **completada** cuando:

✅ Todos los criterios de aceptación (9.1, 9.2, 9.3) están marcados  
✅ Coverage de tests ≥ 85%  
✅ Documentación actualizada (README, inline docs)  
✅ Code review aprobado por lead architect  
✅ Release notes escritas  
✅ QA sign-off en staging  
✅ Preparado para release a producción  

---

## 15. Próximos Pasos (Post-Aprobación)

Si esta propuesta es aprobada:

1. **sdd-spec** (paralelo con design)
   - Escribir requisitos detallados de cada servicio
   - Validar API contracts
   - Tests de integración

2. **sdd-design** (paralelo con spec)
   - Diagramas de secuencia (unlock, encrypt, decrypt)
   - Decisiones de implementación (async/await, error handling)
   - Revisión de seguridad

3. **Implementation (Sprint 1-5)**
   - Seguir timeline 8.1
   - Daily standups
   - Sprint reviews

---

## Anexo A: Referencias

- **SDD v2 (Actual):** `taul_sdd_v_2_markdown.md`
- **Librerías:**
  - [cryptography pub.dev](https://pub.dev/packages/cryptography)
  - [flutter_secure_storage pub.dev](https://pub.dev/packages/flutter_secure_storage)
  - [local_auth pub.dev](https://pub.dev/packages/local_auth)

---

## Anexo B: Glosario

- **AES-256-GCM:** Advanced Encryption Standard, 256-bit key, Galois/Counter Mode (authenticated encryption)
- **Argon2id:** Password hashing function (resistance to GPU/ASIC attacks)
- **FTS5:** SQLite Full-Text Search, version 5
- **Nonce:** Number used once (IV for encryption)
- **Tag (GCM):** Authentication tag (validates ciphertext integrity)
- **flutter_secure_storage:** Secure storage backend (Android Keystore, iOS Keychain)
- **local_auth:** Flutter plugin for biometric authentication
- **Riverpod:** State management for Flutter (successor to Provider)
- **Drift:** Object-relational mapper (ORM) for SQLite in Flutter

---

**Propuesta Finalizada**  
**Versión:** 2.0-Phase2-Proposal v1.0  
**Fecha:** 2025  
**Estado:** 🟡 Pendiente Aprobación  

**Próximo Revisor:** Equipo de Arquitectura / Tech Lead
