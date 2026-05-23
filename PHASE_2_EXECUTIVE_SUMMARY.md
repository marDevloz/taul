# Executive Summary — Fase 2: Cifrado, Vault Seguro, Desbloqueo Biométrico

**Taúl Phase 2 Proposal**

---

## 🎯 Objetivo en Una Frase

Proteger las credenciales de Taúl con cifrado AES-256-GCM, autenticación biométrica y sesiones con timeout automático, manteniendo la velocidad de búsqueda (< 200 ms) y la arquitectura minimalista.

---

## 📊 Snapshot Ejecutivo

| Aspecto | Detalle |
|--------|---------|
| **Problema** | Credenciales en texto plano = riesgo crítico |
| **Solución** | Approach B: Cifrado selectivo de campo `secret` solo |
| **Stack Nuevo** | cryptography + flutter_secure_storage + local_auth + pointycastle |
| **Cambios BD** | +3 columnas, +2 tablas, migración v1→v2 automática |
| **Esfuerzo** | ~85 horas (~2 semanas, 1 person) |
| **Estimación** | 🟡 MEDIO |
| **Riesgo Mayor** | Migración v1→v2 (mitigado con backup automático) |
| **Beneficio** | ✅ Seguridad bancaria en almacén local |

---

## ✅ Alcance Confirmado

### Incluido en Phase 2 ✅

- **Cifrado:** AES-256-GCM para `secret` (NO `content`)
- **Derivación:** Argon2id con parámetros moderados
- **Almacenamiento Seguro:** flutter_secure_storage (Android Keystore / iOS Keychain)
- **Desbloqueo Biométrico:** Huella + Face Recognition (opcional)
- **Sesión:** Cierre automático tras 15 min inactividad + aviso de 1 min
- **Migración:** v1→v2 automática con backup pre-migración
- **UI Mínima:** UnlockScreen + BiometricSettingsScreen + SessionTimeoutDialog
- **Providers:** 5 nuevos providers Riverpod

### Excluido (Diferido) ❌

- ❌ Cifrado de `content` (solo `secret`)
- ❌ Sincronización (Fase 3)
- ❌ Recovery de contraseña (Fase 2.1+)
- ❌ Cambio de contraseña maestra (Fase 3)
- ❌ UI avanzada
- ❌ Auditoría de acceso

---

## 🔧 Cambios Técnicos

### Nuevas Capas de Servicio (3)

```
CryptoService
├── encrypt(plaintext, masterKey) → (cipher, nonce, tag, version)
├── decrypt(cipher, nonce, tag, masterKey) → plaintext
├── deriveMasterKey(password, salt) → bytes
├── generateSalt() → bytes
└── validateNonce(nonce) → bool

BiometricService
├── isAvailable() → bool
├── authenticate(reason) → bool
└── isBiometricEnabled() → bool

SecureStorageService
├── setMasterKey(key)
├── getMasterKey() → bytes?
├── setSalt(salt)
├── setSessionToken(token)
└── getSessionToken() → String?
```

### Schema de Base de Datos (v2)

```sql
-- Tabla entries (modificada)
ALTER TABLE entries ADD COLUMN secret_nonce TEXT;
ALTER TABLE entries ADD COLUMN secret_tag TEXT;
ALTER TABLE entries ADD COLUMN crypto_version INTEGER DEFAULT 1;

-- Tabla nueva: crypto_config
CREATE TABLE crypto_config (
  id INTEGER PRIMARY KEY,
  salt_hex TEXT NOT NULL,
  crypto_version INTEGER DEFAULT 1,
  master_key_hash TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Tabla nueva: sessions
CREATE TABLE sessions (
  id TEXT PRIMARY KEY,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  is_active BOOLEAN DEFAULT 1
);
```

### Riverpod Providers (5 nuevos)

1. `cryptoServiceProvider` — Instancia CryptoService
2. `biometricServiceProvider` — Instancia BiometricService
3. `secureStorageServiceProvider` — Instancia SecureStorageService
4. `masterKeyProvider` — StateNotifier (clave en memoria, volátil)
5. `sessionProvider` — StateNotifier (token + expiración)

---

## 🛡️ Seguridad

| Aspecto | Implementación |
|--------|-----------------|
| Encriptación | AES-256-GCM (AEAD) |
| Derivación | Argon2id(t=3, m=65536, p=4) |
| Almacenamiento | flutter_secure_storage + Android Keystore / iOS Keychain |
| Nonce | Random por cada cifrado, verificación de uniqueness |
| Session | Token efímero, volatile en memoria, timeout 15 min |
| Logs | Cero datos sensibles |
| Clipboard | Timeout 30 seg, borrado automático |
| Biométricos | Local, sin envío remoto |

---

## 📈 Impacto en Rendimiento

| Métrica | v1 (Pre-Phase2) | v2 (Post-Phase2) | Impacto |
|--------|-----------------|-----------------|---------|
| Búsqueda (10k entradas) | < 200 ms | < 200 ms | ✅ Sin cambio |
| Apertura de credencial | N/A | +2-5 ms (descifrado) | ✅ Negligible |
| Cierre de sesión | N/A | < 100 ms | ✅ N/A |
| Unlock con biométrico | N/A | +50-100 ms | ✅ Negligible |
| Unlock con contraseña | N/A | +500-1000 ms (Argon2id) | ⚠️ Aceptable (async) |
| Migración v1→v2 | N/A | +2-5 seg (one-time) | ✅ One-time |

**Conclusión:** Sin degradación material en rendimiento.

---

## 🧪 Criterios de Aceptación

### Funcional ✅

- [ ] Contraseña maestra se crea al iniciar
- [ ] Secrets se cifran en BD
- [ ] Unlock con contraseña funciona
- [ ] Unlock con biométricos funciona (si habilitado)
- [ ] Sesión cierra tras 15 min inactividad
- [ ] Dialog de aviso 1 min antes
- [ ] Descifrado de credenciales es correcto
- [ ] Búsqueda FTS5 < 200 ms (sin degradación)
- [ ] Migración v1→v2 es automática
- [ ] Backup pre-migración existe y es reversible

### No-Funcional ✅

- [ ] AES-256-GCM con autenticación
- [ ] Argon2id derivación
- [ ] Masterkey no sale de flutter_secure_storage
- [ ] Session token es volátil
- [ ] Test coverage ≥ 85%

---

## 📅 Timeline

| Sprint | Duración | Componente |
|--------|----------|-----------|
| 1 | 1.5 sem | CryptoService + Tests |
| 2 | 1 sem | SecureStorage + Biometric + Tests |
| 3 | 1 sem | Migration v1→v2 |
| 4 | 1 sem | UI + Providers |
| 5 | 1 sem | Integración + E2E |
| QA | 0.5 sem | Fixes + Release |
| **TOTAL** | **~5 semanas** | **1 person @ 40h/wk** |

---

## ⚠️ Riesgos Principales

| Riesgo | Probabilidad | Impacto | Mitigación |
|--------|--------------|--------|-----------|
| Pérdida de datos en migración | Media | Crítico | Backup obligatorio + reversibilidad |
| Argon2id demasiado lento | Baja | Medio | Parámetros moderados + async UI |
| Timeout abrupto | Media | Bajo | Dialog de aviso + autoguardado |
| Biométricos fallan | Media | Bajo | Fallback a contraseña (no es obligatorio) |
| flutter_secure_storage no disponible | Baja | Crítico | Fallback a encrypted preferences (con warning) |

---

## 💡 Decisiones Clave

| Decisión | Elegida | Alternativa Rechazada | Razón |
|----------|---------|----------------------|-------|
| Approach | B (selectivo) | A (todo cifrado) | Performance: FTS5 sin overhead |
| Almacenamiento Key | flutter_secure_storage | SharedPreferences | Hardware-backed encryption |
| Timeout | 15 min | 5 min / 30 min | Balance UX-Seguridad |
| Recovery Password | Pérdida total | Recovery key | Simplificar Phase 2 |
| Biométricos | Opcional | Obligatorio | UX flexibility |

---

## 🚀 Fases Posteriores (Roadmap)

**Phase 2.1:** Cambio de contraseña maestra + recovery key  
**Phase 3:** Sincronización manual con cifrado end-to-end  
**Phase 4:** Auditoría de acceso + logs  

---

## 📋 Entregables

Cuando Phase 2 esté DONE:

1. ✅ **PHASE_2_PROPOSAL.md** (este documento extendido)
2. ✅ **Drift Migration Script** (v1 → v2)
3. ✅ **CryptoService + Tests** (100% coverage)
4. ✅ **BiometricService + Tests**
5. ✅ **SecureStorageService + Tests**
6. ✅ **UI Screens** (Unlock + BiometricSettings + SessionTimeout)
7. ✅ **Riverpod Providers** (5 nuevos)
8. ✅ **Integration Tests** (E2E unlock → search → decrypt)
9. ✅ **Documentation** (README Security, Inline Docs)
10. ✅ **Release Notes**

---

## ✋ Next Steps (Si es Aprobada)

**Inmediatamente:**
1. Aprobación de esta propuesta (sign-off)
2. Crear tasks en backlog (1 task por componente)
3. Asignar sprints

**Paralelo (sdd-spec + sdd-design):**
- **sdd-spec:** Escribir requisitos detallados de cada servicio
- **sdd-design:** Diagramas, decisiones de implementación, security review

**Implementation:** Seguir timeline de 5 sprints

---

## 🎓 Conclusión

La **Fase 2** es crítica para la viabilidad de Taúl como producto seguro. Propone una solución **balanceada**:

- ✅ **Seguridad:** AES-256-GCM + Argon2id + flutter_secure_storage
- ✅ **Performance:** Sin degradación (FTS5 intacto)
- ✅ **Simplicity:** Approach B (solo `secret`)
- ✅ **Reversibilidad:** Backup + migration undo
- ✅ **Sostenibilidad:** Arquitectura limpia, servicios abstraídos

**Estimación: MEDIO (85 horas, ~2 semanas)**

**Recomendación:** ✅ **APROBAR** y proceder con sdd-spec + sdd-design en paralelo.

---

**Propuesta:** `sdd/phase-2-crypto-vault/proposal`  
**Estado:** 🟡 Pendiente Aprobación  
**Revisado por:** [Pendiente]  
**Aprobado por:** [Pendiente]
