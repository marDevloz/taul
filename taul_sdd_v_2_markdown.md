# Documento de Diseño de Software (SDD)

# Taúl – Versión 2.0

**Un almacén personal mínimo, rápido, seguro y soberano.**

---

## 1. Visión General

**Taúl** es una aplicación local y minimalista diseñada para almacenar información personal de forma inmediata y recuperarla en segundos.

El sistema está orientado a:

- velocidad de captura,
- recuperación instantánea,
- simplicidad extrema,
- soberanía total de los datos.

Taúl funciona completamente offline. No utiliza servidores externos, cuentas, servicios cloud ni sincronización automática. Toda la información permanece bajo control directo del usuario.

La sincronización entre dispositivos es manual, local y explícita.

---

## 2. Filosofía del Producto

Taúl evoluciona desde un simple vault minimalista hacia una memoria personal soberana y ultrarrápida.

El sistema no intenta convertirse en un "second brain" complejo ni en una plataforma de automatización. La prioridad es maximizar la densidad de recuperación de información con la mínima fricción posible.

Taúl no compite con suites de productividad colaborativas. Su objetivo es simple:

> Guardar algo importante en 3 segundos y encontrarlo en 1.

Principios fundamentales:

- Minimalismo funcional.
- Baja fricción.
- Seguridad por defecto.
- Offline-first.
- Infraestructura cero.
- Rapidez sobre complejidad.
- Control absoluto del usuario.

La experiencia debe sentirse rápida, sobria, determinista y silenciosa, como una herramienta local bien construida.

---

## 3. Objetivos del Sistema

- Capturar información rápidamente.
- Recuperar información instantáneamente mediante búsqueda.
- Mantener secretos protegidos mediante cifrado moderno.
- Operar completamente offline.
- Sincronizar dispositivos manualmente en red local.
- Reducir complejidad operativa y técnica.
- Mantener una arquitectura sostenible a largo plazo.

---

## 4. Principios Arquitectónicos

### 4.1 Sin cuentas ni autenticación remota

Taúl no implementa cuentas, recuperación cloud, identidad remota ni sincronización basada en terceros. El acceso depende exclusivamente de la clave maestra local, el almacenamiento local y la sincronización directa entre dispositivos. Esto reduce la superficie de ataque, la dependencia de infraestructura, la complejidad operacional y los costos de mantenimiento.

### 4.2 Offline First

Toda funcionalidad principal debe operar sin conectividad. La red es un complemento opcional únicamente para la sincronización manual.

### 4.3 Simplicidad antes que automatización

El sistema evita inferencias agresivas, automatizaciones complejas, IA innecesaria, sincronización permanente y procesos en segundo plano costosos.

### 4.4 Arquitectura austera

Cada componente debe justificar su existencia. Se prioriza la mantenibilidad, velocidad, estabilidad, legibilidad y facilidad de depuración.

---

## 5. Casos de Uso Principales

| Caso de uso         | Descripción                         |
|---------------------|-------------------------------------|
| Añadir entrada      | Guardar texto rápidamente           |
| Guardar credencial  | Almacenar usuario y secreto cifrado |
| Buscar en Taúl      | Búsqueda instantánea                |
| Añadir rápida       | Captura mediante sintaxis corta     |
| Editar entrada      | Modificar información               |
| Eliminar entrada    | Soft delete                         |
| Sincronizar         | Intercambio manual local            |
| Resolver conflictos | Mantener ambas versiones            |

---

## 6. Requisitos Funcionales

### 6.1 Gestión de entradas

Cada entrada puede pertenecer opcionalmente a un contexto lógico mediante `topic_key`, lo que permite agrupar información relacionada, navegar contexto compartido, mantener continuidad histórica y relacionar ideas sin jerarquías complejas. El sistema nunca fusiona entradas automáticamente.

Cada entrada posee los siguientes campos:

- `id`
- `type`
- `title`
- `content`
- `metadata`
- `tags`
- `topic_key`
- `secret`
- `created_at`
- `updated_at`
- `version`
- `deleted_at`

### 6.2 Tipos de entrada

Tipos iniciales: `GLOSARIO`, `NOTA`, `IDEA`, `CREDENCIAL`. Los tipos modifican únicamente la representación visual, el comportamiento y las validaciones. No existen jerarquías complejas de entidades.

### 6.3 Quick Add

Taúl permite capturas rápidas mediante sintaxis mínima. Ejemplos:

```
serendipia: hallazgo afortunado
```

```
+ gmail juan@gmail.com
```

```
! idea rápida sobre sincronización
```

La aplicación puede sugerir un tipo, pero nunca clasifica agresivamente. La decisión final siempre es del usuario.

### 6.4 Progressive Disclosure

La recuperación de información ocurre en tres niveles:

- **Nivel 1 — Search Snapshot**: resultados compactos con título, tipo, fecha y etiquetas principales. Objetivo: escaneo visual rápido, mínima carga cognitiva, velocidad percibida alta.
- **Nivel 2 — Context Preview**: al seleccionar un resultado se muestra vista previa parcial, metadata, entradas relacionadas, historial resumido y contexto temporal. Todavía no se carga ni descifra contenido sensible completo.
- **Nivel 3 — Full Entry**: solo al abrir explícitamente se muestra el contenido completo, los secretos descifrados, el historial completo y las versiones anteriores. Esto mejora el rendimiento, la claridad visual y la seguridad operacional.

### 6.5 Búsqueda instantánea

Se utiliza SQLite FTS5 para indexar: título, contenido textual no sensible, etiquetas y nombres de usuario. El campo `secret` jamás se indexa.

### 6.6 Entradas relacionadas

Taúl puede mostrar automáticamente contexto relacionado basado en `topic_key`, etiquetas compartidas, proximidad temporal y coincidencias FTS5. El sistema nunca reorganiza agresivamente los resultados ni altera el comportamiento esperado del usuario.

### 6.7 Historial de versiones

Las entradas de tipo `NOTA`, `IDEA` y `GLOSARIO` pueden conservar versiones históricas. Las credenciales no almacenan historial del campo secreto por razones de seguridad. Cada modificación importante genera un snapshot con timestamp y checksum. El usuario puede revisar versiones anteriores y restaurar estados previos. No existen merges complejos, branching ni edición colaborativa.

### 6.8 Soft Delete

Las entradas eliminadas se marcan mediante `deleted_at`. Nunca se eliminan físicamente de forma automática.

### 6.9 Sincronización manual

La sincronización es iniciada por el usuario, ocurre únicamente en red local, funciona solo con el vault desbloqueado e intercambia únicamente cambios recientes. El proceso es:

1. El usuario pulsa "Sincronizar".
2. El dispositivo publica un servicio local vía mDNS.
3. El otro dispositivo descubre el servicio.
4. Se valida un código de emparejamiento.
5. Se intercambian las entradas modificadas.
6. La sesión finaliza automáticamente.

### 6.10 Resolución de conflictos

En caso de conflicto nunca se sobrescriben datos silenciosamente: se conservan ambas versiones y el usuario decide posteriormente. Esto reduce la complejidad y el riesgo de pérdida accidental.

### 6.11 Backups automáticos

El sistema crea backups automáticos periódicamente, cuando existen cambios importantes y antes de migraciones. Se utiliza el formato `taul_YYYY_MM_DD_HHmmss.db.zst` y se mantiene una rotación máxima de 7 backups.

---

## 7. Requisitos No Funcionales

### 7.1 Rendimiento

Taúl prioriza la recuperación rápida de información sobre la complejidad visual. La interfaz debe recuperar contexto útil rápidamente, minimizar el ruido visual y reducir la navegación innecesaria.

Objetivos de rendimiento:

- Apertura rápida.
- Búsqueda < 200 ms.
- Carga fluida con miles de registros.

Métrica de validación: dataset de referencia de 10.000 entradas, benchmark local con FTS5, promedio inferior a 200 ms en hardware estándar.

### 7.2 Seguridad

- AES-256-GCM.
- Argon2id.
- TLS local.
- Tokens efímeros.
- Secretos fuera del índice.
- Logs sin información sensible.

### 7.3 Privacidad

Los datos nunca abandonan el control del usuario.

### 7.4 Portabilidad

Una única base de datos SQLite por dispositivo.

### 7.5 Testabilidad

Toda lógica crítica debe poder probarse de forma aislada.

---

## 8. Arquitectura del Sistema

Se adopta una arquitectura limpia orientada a dominio:

```
/lib
 ├── core/
 ├── domain/
 │    ├── entities/
 │    ├── repositories/
 │    └── usecases/
 ├── infrastructure/
 │    ├── database/
 │    ├── sync/
 │    ├── crypto/
 │    ├── storage/
 │    ├── backup/
 │    └── logging/
 └── ui/
      ├── screens/
      ├── widgets/
      └── theme/
```

---

## 9. Stack Tecnológico

### Plataforma

- Flutter

### Estado y DI

- Riverpod

### Base de Datos

- SQLite
- Drift
- FTS5

### Criptografía

- cryptography
- flutter_secure_storage
- local_auth

### Sincronización

Se prioriza la simplicidad operacional. Tecnologías evaluadas: HTTP local, WebSocket local. gRPC permanece como opción futura si realmente es necesario.

### Utilidades

- freezed
- json_serializable
- logger
- mocktail
- go_router

---

## 10. Modelo de Dominio

### Entidad Principal: Entry

La entidad `Entry` representa una unidad mínima de memoria recuperable. Puede relacionarse mediante `topic_key`, mantener historial de versiones y participar en recuperación contextual.

```
Entry
 ├── id
 ├── type
 ├── title
 ├── content
 ├── metadata
 ├── tags
 ├── topic_key
 ├── secret
 ├── createdAt
 ├── updatedAt
 ├── version
 └── deletedAt
```

### VaultState

Estados: `LOCKED`, `UNLOCKED`, `PAIRING`, `SYNCING`, `ERROR`.

### Conflict

```
Conflict
 ├── id
 ├── entryId
 ├── localVersion
 ├── remoteVersion
 ├── resolution
 └── createdAt
```

---

## 11. Invariantes de Dominio

- Los secretos nunca se indexan.
- El vault debe estar desbloqueado para sincronizar.
- La clave maestra nunca se almacena en texto plano.
- Ningún log puede contener secretos.
- Las sesiones expiran automáticamente.
- Los conflictos nunca destruyen información silenciosamente.

---

## 12. Estrategia de Seguridad

### 12.1 Clave maestra

Derivada mediante Argon2id. La configuración puede ajustarse dinámicamente según la capacidad del dispositivo para mantener tiempos de desbloqueo rápidos.

### 12.2 Cifrado

- AES-256-GCM.
- IV aleatorio por operación.
- DEKs independientes por entrada sensible.

### 12.3 Biometría

La biometría no reemplaza la clave maestra, solo desbloquea temporalmente la sesión.

### 12.4 Logs

Clasificación: `DEBUG`, `INFO`, `SECURITY`, `ERROR`. Prohibido registrar secretos, claves, tokens o contenido descifrado.

---

## 13. Estrategia de Sincronización

### Descubrimiento

mDNS: `_taul._tcp`

### Seguridad

- TLS local autofirmado.
- Código de emparejamiento.
- Tokens efímeros.

### Intercambio

Se sincronizan únicamente entradas modificadas desde la última sesión.

### Filosofía

La sincronización no es automática, no permanece activa, no depende de internet y no requiere infraestructura externa. La implementación inicial prioriza HTTP local o WebSocket local con serialización tipada y TLS local. gRPC permanece como alternativa futura si la complejidad lo justifica.

---

## 14. Migraciones de Base de Datos

Políticas:

- Migraciones forward-only.
- Nunca modificar migraciones históricas.
- Backup automático previo a migración.
- Compatibilidad mínima con versiones N-1.

---

## 15. Vistas de la Interfaz

La interfaz sigue el principio: *mínima navegación, máxima recuperación*. Evita múltiples pantallas complejas y prioriza flujos rápidos y predecibles.

### 15.1 HomeView

Vista principal y núcleo de la aplicación. Contiene:

- Buscador global.
- Filtros rápidos por tipo.
- Lista de resultados.
- Botón de sincronización.
- Botón de añadir.

Comportamientos: búsqueda reactiva instantánea, scroll fluido, snapshots compactos, apertura rápida de entradas. Objetivo: capturar, buscar y recuperar información.

**Mockup de HomeView:**

```
┌─────────────────────────────┐
│  🔍 Buscar en Taúl...      │
├─────────────────────────────┤
│ [Todas] [📖] [🔐] [📝] [💡] │
├─────────────────────────────┤
│ ┌─────────────────────────┐ │
│ │ 🟢 serendipia           │ │
│ │ Hallazgo afortunado     │ │
│ └─────────────────────────┘ │
│ ┌─────────────────────────┐ │
│ │ 🔐 Gmail                │ │
│ │ ••••••••                │ │
│ └─────────────────────────┘ │
│                             │
│ [🔄 Sincronizar] [ ＋ ]     │
└─────────────────────────────┘
```

### 15.2 EntryPreviewView

Vista contextual intermedia que se activa al seleccionar una entrada. Muestra: preview parcial, metadata, etiquetas, `topic_key`, entradas relacionadas, historial resumido y fechas. No muestra secretos completos automáticamente. Objetivo: entregar contexto sin romper velocidad.

### 15.3 EntryDetailView

Vista completa de la entrada. Muestra contenido completo, secretos descifrados bajo interacción explícita, historial de versiones, acciones de edición y restauración de versiones. Comportamientos: desbloqueo temporal de secretos, ocultamiento automático tras timeout, edición rápida. Objetivo: acceso completo y seguro.

### 15.4 QuickAddSheet

Hoja inferior minimalista para captura rápida. Permite escribir inmediatamente, detectar tipo sugerido y guardar en segundos. Gramática definida:

- `texto: contenido` → `title` = texto, `content` = contenido, tipo sugerido `GLOSARIO`.
- `+ servicio usuario@correo.com` → `title` = servicio, `username` = usuario@correo.com, `secret` = vacío, tipo sugerido `CREDENCIAL`.
- `! idea rápida` → `content` = texto completo, tipo sugerido `IDEA`.

La detección automática nunca sobrescribe la decisión manual del usuario. Objetivo: reducir la fricción de captura.

### 15.5 SyncView

Vista mínima para sincronización manual. Muestra dispositivos detectados, estado de conexión, código de emparejamiento, progreso y conflictos encontrados. La sincronización nunca permanece activa en segundo plano.

### 15.6 ConflictView

Vista simple de resolución de conflictos. Muestra versión local, versión remota, timestamps y diferencias resumidas. Opciones: conservar ambas, restaurar versión anterior o archivar conflicto. No existen merges automáticos complejos.

### 15.7 TimelineView

Vista opcional y ligera, planeada para Fase 2+. Accesible desde filtros avanzados, `topic_key` o entradas relacionadas. Muestra entradas recientes, actividad cronológica, agrupaciones por `topic_key` y contexto temporal. No debe convertirse en el flujo principal de navegación. Objetivo: recuperar continuidad contextual.

### 15.8 SettingsView

Configuración mínima que incluye backups, exportación, restauración, biometría, seguridad, limpieza manual y dispositivos emparejados. Objetivo: mantener control operativo sin complejidad.

### 15.9 Principios Visuales

La UI debe mantenerse sobria, silenciosa, rápida, consistente y altamente legible. Se evitan animaciones excesivas, dashboards complejos, widgets innecesarios, sobrecarga visual y gamificación. El contenido es el protagonista.

---

## 16. Estrategia de Backups

- **Automáticos**: periódicos, previos a migraciones y bajo cambios importantes.
- **Compresión**: Zstandard.
- **Restauración**: manual desde configuración.

---

## 17. Plan de Pruebas

### Unitarias

- Cifrado, derivación de claves, resolución de conflictos, backups.

### Integración

- Drift, sincronización local, conflictos, restauración.

### UI

- Renderizado, búsqueda, flujo de captura.

---

## 18. Roadmap Inicial

- **Fase 1**: estructura Flutter, entidades, Drift, FTS5, UI mínima.
- **Fase 2**: cifrado, vault, desbloqueo biométrico.
- **Fase 3**: sincronización local, emparejamiento, conflictos.
- **Fase 4**: backups, exportación, refinamiento UX.

---

## 19. Registro de Decisiones de Arquitectura (ADR)

- **ADR-001**: Flutter como framework multiplataforma.
- **ADR-002**: Riverpod para estado y DI.
- **ADR-003**: SQLite + Drift como almacenamiento principal.
- **ADR-004**: AES-256-GCM + Argon2id.
- **ADR-005**: Sincronización local manual.
- **ADR-006**: Conflictos conservando ambas versiones.
- **ADR-007**: FTS5 sin indexar secretos.
- **ADR-008**: Backups locales con Zstandard.
- **ADR-009**: Biometría únicamente como desbloqueo temporal.
- **ADR-010**: Sin cuentas ni autenticación remota.
- **ADR-011**: Progressive Disclosure para recuperación contextual.
- **ADR-012**: Topic Keys para agrupación lógica.
- **ADR-013**: Historial minimalista de versiones.
- **ADR-014**: Recuperación contextual basada en FTS5 y metadata.

---

## 20. Evolución Estratégica

Taúl evoluciona desde un simple almacén de notas hacia una memoria personal soberana. Sin embargo, mantiene límites deliberados: no implementa IA generativa, embeddings, búsqueda semántica pesada, automatización agresiva, sincronización cloud ni colaboración multiusuario.

La prioridad continúa siendo simplicidad, velocidad, predictibilidad y soberanía local. El valor principal del sistema no está únicamente en almacenar información, sino en recuperar rápidamente contexto útil con mínima fricción.

---

## 21. Conclusión

Taúl está diseñado como una herramienta personal rápida, privada y sostenible. El sistema prioriza velocidad, simplicidad, seguridad, control local y mantenibilidad. Cada decisión arquitectónica busca evitar complejidad innecesaria y mantener el producto pequeño, confiable y durable en el tiempo.