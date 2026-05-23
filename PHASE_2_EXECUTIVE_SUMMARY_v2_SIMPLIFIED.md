# Executive Summary — Fase 2 (v2): Protección Opcional de Entradas

**Taúl Phase 2 Proposal — SIMPLIFIED & USER-CENTRIC**

---

## 🎯 Objetivo en Una Frase

**Permitir que usuarios protejan entradas individuales con una contraseña maestra única, eliminando toda fricción innecesaria.**

---

## 📊 Snapshot Ejecutivo

| Aspecto | Detalle |
|--------|---------|
| **Problema** | Credenciales sensibles en texto plano; usuarios quieren protección selectiva, NO global |
| **Solución** | Entry-level `requiresAuth` boolean + AES-256-GCM + Argon2id |
| **Cambio vs v1** | ❌ Eliminado: vault global, timeout 15min, flutter_secure_storage, biometría mandatory |
| **Stack Nuevo** | `cryptography` v2.7.0 + `pointycastle` v3.10.0 (solo 2 deps) |
| **Cambios BD** | +4 columnas, +1 tabla de configuración (simple) |
| **Esfuerzo** | 🟢 **~20 horas (~1 semana, 1 person)** |
| **Estimación** | **LOW** (vs **MEDIUM** 85h de v1) |
| **Riesgo Mayor** | Minimal (no vault state, no timeout, no migration complexity) |
| **Beneficio** | ✅ User-centric, zero friction, minimalista |

---

## ✅ Alcance Confirmado (IN / OUT)

### Incluido en Phase 2 ✅

| Componente | Detalle |
|-----------|---------|
| **Data Model** | `Entry.requiresAuth`, `encryptedSecret`, `cipherNonce`, `cipherTag` |
| **Cifrado** | AES-256-GCM para `secret` cuando `requiresAuth=true` |
| **Derivación** | Argon2id(t=2, m=65536, p=1) |
| **Contraseña Maestra** | Una global para TODAS las entradas protegidas |
| **Setup** | Pregunta UNA SOLA VEZ (al proteger primera entrada) |
| **UI Flows** | Create/Edit con toggle, View con [Reveal Secret] button, Search con 🔒 indicator |
| **Servicios** | `EntryAuthService` (1 servicio, mínimo) |
| **Providers** | 3 nuevos providers Riverpod (mínimo) |
| **DB Schema** | v1→v2 simple (append columns + new config table) |
| **Testing** | 40-50 unit/integration tests |
| **Biometría** | ❌ Diferido (Phase 2.1) — not this sprint |

### Excluido (Diferido) ❌

| Item | Razón |
|------|-------|
| ❌ Vault global con timeout | Innecesario; per-entry protection |
| ❌ flutter_secure_storage | No necesario; hash en BD es suficiente |
| ❌ Session timeout automático | Cero fricción requerido |
| ❌ Biometría (huella, face) | Nice-to-have, Phase 2.1 |
| ❌ Cambio de contraseña maestra | Phase 2.1 |
| ❌ Recovery password | Phase 2.1+ |
| ❌ Cifrado de `content` | Solo `secret` |

---

## 🔄 User Journey (Antes vs Después)

### ANTES (Con Vault Global — Old)

```
User wants to access credenciales:
  1. App start → "Unlock vault?" 
  2. Password input (500-1000ms Argon2id) ⏳
  3. Unlock successful
  4. Search for "twitter"
  5. View credential
  6. After 15 min inactividad → ⚠️ "Session expired"
  7. Re-unlock → password input again ⏳

Friction: ❌ ALTA (3+ prompts, timeout, delay)
```

### DESPUÉS (Per-Entry Protection — New) ✅

```
User wants to access credenciales:
  1. App start → Normal (sin prompts)
  2. Search for "twitter"
  3. View credential (normal, no protection)
  4. View credential (protegida) → [🔒 Reveal Secret] button
  5. Click Reveal → password input (1x, primeras protecciones)
  6. See secret
  7. Auto-hide 30s
  8. Continue using app normally (sin timeout)

Friction: ✅ CERO (user controls when to auth, no forced timeout)
```

---

## 💡 Key Decisions vs Old Proposal

| Decisión | Old (Vault) | New (Per-Entry) | Winner |
|----------|-----------|----------------|--------|
| **Encryption** | All-or-nothing | Selective (user decides) | ✅ New |
| **Authentication** | Prompt at startup | Prompt on-demand | ✅ New |
| **Session** | Global timeout 15min | No timeout (volatile key) | ✅ New |
| **Infrastructure** | Vault state machine | Entry-level boolean | ✅ New |
| **Complexity** | 5+ providers, 3 services | 3 providers, 1 service | ✅ New |
| **Performance** | 500-1000ms unlock delay | 2-5ms per decrypt | ✅ New |
| **Biometría** | Mandatory | Optional (future) | ✅ New |
| **Effort** | 85 hours | 20 hours | ✅ New |
| **User Friction** | High (forced auth) | Zero (user controlled) | ✅ New |

---

## 🛡️ Seguridad Garantizada

| Aspecto | Implementación |
|--------|-----------------|
| **Cifrado** | AES-256-GCM (Authenticated Encryption) |
| **Derivación** | Argon2id (t=2, m=65536, p=1) |
| **Nonce** | 12 bytes random per encryption, verified |
| **GCM Tag** | 16 bytes, previene tampering |
| **Master Password** | Argon2id hash en BD (NO plaintext) |
| **Derived Key** | En memoria, cleared on app exit |
| **Threat: Plaintext theft** | ✅ Mitigado (AES-256-GCM) |
| **Threat: Rainbow table** | ✅ Mitigado (Argon2id + salt) |
| **Threat: Tampering** | ✅ Mitigado (GCM tag) |
| **Threat: Nonce reuse** | ✅ Mitigado (Random.secure) |

---

## 📈 Performance Impact

| Métrica | v1 (Pre-Phase2) | v2 (Post-Phase2) | Impacto |
|--------|-----------------|-----------------|---------|
| **App startup** | ~100ms | ~100ms | ✅ Sin cambio |
| **Search (10k entries)** | < 200 ms | < 200 ms | ✅ Sin cambio |
| **View unprotected entry** | < 10 ms | < 10 ms | ✅ Sin cambio |
| **View protected entry (decrypt)** | N/A | +2-5 ms | ✅ Negligible |
| **Reveal Secret (password verification)** | N/A | +200-300 ms | ✅ Acceptable (async) |
| **Unlock derived key (Argon2id)** | N/A | +200-300 ms | ✅ One-time per session |

**Conclusión:** Sin degradación perceptible en performance.

---

## 📅 Timeline & Effort

### Sprint Breakdown

| Sprint | Duración | Componente | Horas |
|--------|----------|-----------|-------|
| **Sprint 1** | 2 días | EntryAuthService + unit tests | 6h |
| **Sprint 1** | 2 días | Riverpod providers + DB migration | 4h |
| **Sprint 2** | 1.5 días | UI: EntryDetailView + CreateEntryForm | 5h |
| **Sprint 2** | 0.5 días | UI: MasterPasswordSetupDialog | 2h |
| **Sprint 3** | 1 día | Integration + widget tests | 2h |
| **Sprint 3** | 0.5 días | Documentation + README | 1h |
| **TOTAL** | **1 week** | **~20 hours** | **~20h** |

**Timeline realista:** 1 person, 40h/week → completo en 1 sprint

---

## ⚠️ Riesgos (Mínimos)

| Riesgo | Probab. | Impacto | Mitigación | Status |
|--------|---------|--------|-----------|--------|
| **Argon2id perf** | Baja | Bajo | t=2 (200ms acceptable) | 🟢 OK |
| **Nonce reuse** | Muy baja | Crítico | Random.secure() + tests | 🟢 OK |
| **GCM tampering** | Muy baja | Crítico | Use standard library | 🟢 OK |
| **Master pwd loss** | Media | Crítico | By design (Phase 2.1 recovery) | 🟢 OK |
| **DB corruption** | Muy baja | Bajo | Simple schema (no complex migration) | 🟢 OK |

**Conclusión:** Riesgos MINIMALES vs Old Proposal (85h, MEDIUM risk)

---

## 🧪 Criterios de Aceptación

### Funcional ✅

- [ ] Create entry with `requiresAuth=true`
- [ ] First protection → master password setup
- [ ] Master password stored as Argon2id hash
- [ ] EntryDetailView shows [Reveal Secret] button
- [ ] Click Reveal → password input → decrypt
- [ ] Secret shown, auto-hide 30s
- [ ] Unprotected entries unchanged
- [ ] All entry types supportable
- [ ] Search returns 🔒 indicator
- [ ] FTS5 < 200 ms (no degradation)

### Non-Funcional ✅

- [ ] AES-256-GCM with GCM tag
- [ ] Argon2id(t=2, m=65536, p=1)
- [ ] Nonce uniqueness guaranteed
- [ ] No plaintext in logs
- [ ] Test coverage ≥ 80%
- [ ] Critical paths 100% coverage

---

## 💰 ROI (Return on Investment)

| Metrica | Antes | Después | Ganancia |
|--------|-------|---------|----------|
| **Time to implement** | 85 hours | 20 hours | ⏱️ 4x más rápido |
| **Complexity** | 5+ providers, 3 services | 3 providers, 1 service | 🔧 3x más simple |
| **User friction** | High (forced auth) | Zero (user controlled) | 😊 Better UX |
| **Performance** | Startup delay (500-1000ms) | No startup delay | 🚀 Better performance |
| **Risk level** | MEDIUM | LOW | 🛡️ Lower risk |
| **Security** | ✅ Good (all encrypted) | ✅ Good (selective) | = Equal security |
| **Maintenance** | High (vault state) | Low (simple) | 👍 Easier to maintain |
| **Future extensibility** | Moderate | High (per-entry design) | 🧩 Better foundation |

---

## 🎓 Conclusión

**Phase 2 (v2)** es una propuesta **balanceada, pragmática, y minimalista:**

✅ **User-Centric:** User elige qué proteger (cero fricción)  
✅ **Segura:** AES-256-GCM + Argon2id (suficiente para credenciales)  
✅ **Simple:** 1 servicio, 3 providers, 20 horas  
✅ **Rápida:** Sin degradación en performance (FTS5 intacto)  
✅ **Mantenible:** Minimal infrastructure, clean architecture  
✅ **Baja Riesgo:** Riesgos identificados y mitigados  

**vs Old Proposal (Vault Global):**
- 4x más rápido de implementar
- 3x más simple
- Zero user friction
- Low risk vs MEDIUM risk

**Estimación: 🟢 LOW (20 horas, ~1 semana)**

**Recomendación:** ✅ **APROBAR INMEDIATAMENTE** y proceder con sdd-spec + sdd-design.

---

## 📋 Próximos Pasos

### If Approved ✅

1. **sdd-spec:** Requisitos detallados (2-3 horas)
2. **sdd-design:** Diagramas + security review (3-4 horas)
3. **Implementation:** Seguir sprint plan (20 horas)
4. **QA + Release:** 2-3 horas

### Total Timeline: 2.5 weeks end-to-end

---

## Sign-Off

**Propuesta:** `sdd/phase-2-entry-protection-optional/proposal`  
**Versión:** 2.1 (Simplified & User-Centric)  
**Estado:** 🟡 Pendiente Aprobación  

---

**Documento:** `PHASE_2_EXECUTIVE_SUMMARY_v2_SIMPLIFIED.md`  
**Fecha:** 2025  
**Responsable:** Architecture Team  
