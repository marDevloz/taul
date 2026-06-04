# Especificación: Tags con Colores

## Propósito

Permitir asignar colores a los tags por entrada usando una paleta fija de 16 colores, mostrar indicadores visuales (barra de acento, punto, chip coloreado) en toda la interfaz, y mezclar colores vía promedio HSL para entradas con múltiples tags.

---

## Requisitos Funcionales

| ID | Descripción |
|----|-------------|
| **FR-01** | El sistema DEBE migrar la base de datos de esquema v5 a v6 agregando la columna `tags_color TEXT` a la tabla `entries`. |
| **FR-02** | La entidad `Entry` DEBE incluir un campo `Map<String, String> tagsColors` (tagName → hex). |
| **FR-03** | El DAO DEBE codificar/decodificar `tagsColors` como JSON en la columna `tags_color`. |
| **FR-04** | El sistema DEBE definir una paleta fija de exactamente 16 colores en una grilla 4×4. No DEBE permitir colores fuera de esta paleta. |
| **FR-05** | El sistema DEBE calcular un color mezclado promediando hue, saturation y lightness (HSL) cuando una entrada tiene múltiples tags con colores asignados. Si ningún tag tiene color, DEBE usar gris (`#9E9E9E`). |
| **FR-06** | EntryCard en vista grilla DEBE mostrar una barra de acento izquierda de 4px en el color mezclado (o gris por defecto). |
| **FR-07** | EntryCard en vista lista DEBE mostrar un punto coloreado junto al título en el color mezclado (o gris por defecto). |
| **FR-08** | EntryDetailView DEBE mostrar una barra de acento en el contenedor del cuerpo con el color mezclado. |
| **FR-09** | Los chips de tag en la fila de filtros DEBEN mostrar el color asignado como color de fondo. |
| **FR-10** | Los chips de tag en EntryDetailView DEBEN mostrar el color asignado como fondo y DEBEN abrir el `PalettePicker` al mantener presionado (long-press). |
| **FR-11** | El sistema DEBE incluir un widget `PalettePicker` que muestre los 16 colores en una grilla 4×4 de círculos seleccionables. |
| **FR-12** | Seleccionar un color en el `PalettePicker` DEBE asignar ese color al tag en `tagsColors` para la entrada actual y DEBE persistirse al guardar la entrada. |
| **FR-13** | `CreateEntry` y `UpdateEntry` DEBEN aceptar un parámetro `tagsColors` opcional. |

## Requisitos No Funcionales

| ID | Descripción | Criterio de verificación |
|----|-------------|--------------------------|
| **NFR-01** | Entradas existentes sin `tags_color` (previas a v6) DEBEN mostrar indicadores en gris por defecto. Sin errores al leer filas legacy. | Probar con DB pre-v6. |
| **NFR-02** | `_fromMap` DEBE manejar `null` o campo ausente en `tags_color` retornando un mapa vacío. | Test con null y campo faltante. |
| **NFR-03** | El cálculo de mezcla HSL DEBE ejecutarse sincrónicamente y completarse en <1ms para ≤10 tags. | Medición en unit test. |
| **NFR-04** | `tagsColors` DEBE hacer round-trip DAO → DB → DAO → Entry sin pérdida de datos. | Comparación exacta del mapa. |
| **NFR-05** | El índice FTS5 DEBE indexar solo nombres de tags, no colores. | Sin cambios en esquema FTS5 existente. |
| **NFR-06** | La paleta de 16 colores DEBE ser idéntica en todas las instancias (constante compartida). | Todos los widgets referencian la misma constante. |
| **NFR-07** | `tags_color` DEBE almacenarse como TEXT con JSON. Migración aditiva, sin nuevas tablas. | Verificar schema post-migración. |

---

## Escenarios de Aceptación

### Escenario 1: Entrada sin tags

- **GIVEN** una entrada que no tiene ningún tag
- **WHEN** se muestra en cualquier vista (grilla, lista, detalle)
- **THEN** no se muestra ningún indicador de color (sin barra, sin punto, sin chip coloreado)

### Escenario 2: Entrada con 1 tag con color asignado

- **GIVEN** una entrada con un tag "urgente" que tiene asignado `#E06C75` en `tagsColors`
- **WHEN** se muestra la entrada en la grilla
- **THEN** la barra de acento izquierda se renderiza en `#E06C75`
- **AND** en la vista de lista se muestra un punto `#E06C75`
- **AND** en la vista de detalle el chip del tag muestra fondo `#E06C75`

### Escenario 3: Entrada con 1 tag sin color asignado

- **GIVEN** una entrada con un tag "general" que NO tiene entrada en `tagsColors`
- **WHEN** se muestra en cualquier vista
- **THEN** los indicadores (barra, punto, barra de detalle) se renderizan en gris `#9E9E9E`
- **AND** el chip del tag se muestra sin color de fondo (estilo por defecto)

### Escenario 4: Entrada con 3 tags con 3 colores (mezcla HSL)

- **GIVEN** una entrada con tags "rojo" (`#E06C75`), "azul" (`#61AFEF`), "verde" (`#98C379`) en `tagsColors`
- **WHEN** se calcula el color mezclado
- **THEN** el resultado DEBE ser el promedio aritmético de los tres valores HSL (hue, saturation, lightness)
- **AND** ese color mezclado se usa en la barra de acento de grilla, el punto de lista y la barra de detalle
- **AND** los chips individuales mantienen su color asignado individual

### Escenario 5: Long-press → seleccionar color → asignación

- **GIVEN** una entrada en vista de detalle con un chip de tag visible sin color asignado
- **WHEN** el usuario mantiene presionado (long-press) el chip
- **THEN** se abre el `PalettePicker` mostrando una grilla 4×4 con 16 círculos de color
- **WHEN** el usuario selecciona un color de la grilla
- **THEN** el color se asigna a ese tag en `tagsColors` para la entrada actual
- **AND** el chip cambia inmediatamente al nuevo color de fondo
- **AND** al guardar la entrada, `tagsColors` se persiste en la base de datos

### Escenario 6: Entrada legacy con columna tags_color NULL

- **GIVEN** una entrada creada antes de la migración v6 (columna `tags_color` = NULL)
- **WHEN** `_fromMap` procesa la fila
- **THEN** retorna un `Map<String, String>` vacío para `tagsColors`
- **AND** los indicadores se renderizan en gris
- **AND** no se muestra ningún chip con color de fondo

### Escenario 7: Tag chip en fila de filtros con color

- **GIVEN** un tag "trabajo" con color asignado en `tagsColors` de al menos una entrada
- **WHEN** el tag aparece como chip en `TagFilterRow`
- **THEN** el chip DEBE mostrar el color asignado como color de fondo
- **AND** si el mismo tag no tiene color en ninguna entrada, el chip se muestra sin color de fondo

---

## Criterios de Éxito

- [ ] La columna `tags_color` existe en SQLite post-migración v6, con valor NULL por defecto para filas existentes
- [ ] `Entry` hace round-trip de `tagsColors` a través de DAO → DB → DAO sin pérdida de datos
- [ ] EntryCard grilla muestra barra de acento izquierda de 4px en el color correspondiente
- [ ] EntryCard lista muestra punto coloreado junto al título
- [ ] EntryDetailView muestra barra de acento en el cuerpo
- [ ] Chips de tag en filtros y vista de detalle se renderizan con color de fondo asignado
- [ ] Long-press en chip de detalle abre PalettePicker 4×4
- [ ] Seleccionar un color lo asigna al tag (por entrada) y persiste al guardar
- [ ] Entradas con múltiples tags muestran color mezclado vía promedio HSL
- [ ] Todas las pruebas existentes pasan sin modificaciones
- [ ] Nuevas pruebas unitarias cubren: mezcla HSL (0, 1, 3, 10 tags), límites de paleta, null handling en DAO

## Fuera del Alcance

- Registro global de tags o colores compartidos entre entradas
- Selector de color libre (HSV/HSL/rueda de color/picker RGB)
- Reconciliación automática de colores al renombrar un tag (edge case aceptado como menor)
- Exportación o importación de colores en formato de backup
- Búsqueda o filtrado de entradas por color
- Cambios en el índice FTS5 o en el esquema de búsqueda de texto completo
- Configuración o personalización de la paleta por usuario
- Temas claros/oscuros para los colores de la paleta

---

## Especificaciones Afectadas

Este cambio no modifica especificaciones existentes en `openspec/specs/`. Es una **nueva capacidad** que convive con el comportamiento actual de tags. No hay especificaciones previas de tags que modificar.

| Domino | Tipo | Requerimientos | Escenarios |
|--------|------|----------------|------------|
| Tags con Colores | Nueva especificación completa | 13 funcionales + 7 no funcionales | 7 escenarios |

### Cobertura de escenarios

- **Happy paths**: 5/7 — Escenarios 1-4 (visualización), 7 (filtros)
- **Interacción usuario**: 1/7 — Escenario 5 (palette picker)
- **Edge cases**: 1/7 — Escenario 6 (null legacy)

### Siguiente paso

Listo para **sdd-design** (diseño técnico: widget structure, provider architecture, TagColorMixer contract).
