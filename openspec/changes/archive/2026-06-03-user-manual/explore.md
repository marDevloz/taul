# Exploration: user-manual

## Current State

No user-facing documentation exists beyond:
- **README.md** — 38-line overview with principles, stack, and a brief master password description
- **SECURITY.md** — 161-line developer-oriented security architecture (key hierarchy, backup codes, crypto primitives, rate limiting, threats mitigated)
- **In-app shortcuts sheet** — minimal keyboard shortcuts + quick-add syntax hints (accessible by tapping "Taúl" title in AppBar)
- **openspec/specs/** — two specs (`master-password-settings`, `master-password-recovery`) — these are developer-facing spec documents, not user documentation
- **PHASE_2_*.md** — extensive but purely project management/architecture docs for the development team

No `docs/` folder exists. No help screen. No onboarding flow.

## Features That Need Documentation

### 1. Entry Types
- **Note** — free text, Markdown rendered
- **Idea** — prefixed with `!`
- **Glossary** — `Term:definition` format
- **Credential** — service, username, password, URL fields

### 2. Quick-Add System (QuickAddSheet)
- Auto-detection of entry type from text
- Explicit title syntax: `Title# text`
- Idea prefix: `!idea text`
- Glossary syntax: `Term:definition`
- Credential syntax: `service*user*pass*url`
- Inline tags: `-#tag1 -#tag2`
- Manual type override via dropdown
- Live parse preview (shows detected type, title, tags)
- Hints/chips for each type
- Quick credential entry redirects to full credential form

### 3. Home View
- Entry list (responsive: mobile = single column, tablet = 2 col, desktop = 3 col)
- Entry cards with type icon, title, content preview, date
- **Snake FAB filters**: type filter + tag filter (expandable with staggered animation)
- Filter state shown on collapsed FAB
- Quick-add FAB (+) always at bottom
- **Search bar**: toggle via AppBar button or Ctrl+F, FTS5 full-text search
- **Empty states**: 3 variants (empty vault, filtered-no-results, search-no-results)
- **Selection mode**: long-press to enter, select multiple entries, merge or cancel
- **Inline expand**: tap card to expand/collapse content inline (not for credentials)
- **Copy content**: copy button on expanded cards
- **Secure entry gate**: master password dialog for secure tags on tap/double-tap
- **Double-tap**: navigate to detail view (bypass expand for credentials)

### 4. Entry Detail View
- Markdown content rendering
- Selectable text (long-press to copy)
- Type badge chip
- Tag chips with colors (tap to filter by tag, long-press to change color)
- Timestamps: created, updated, version
- **Navigation**: prev/next buttons, Ctrl+Arrow keys, Ctrl+Tab / Ctrl+Shift+Tab
- **Keyboard shortcuts**: Ctrl+E (edit), Delete (trash)
- **Copy button**: copies title + content to clipboard (non-credentials only)

### 5. Edit Entry
- Title, content, tags (comma-separated), type selector
- **Tag autocomplete**: 300ms debounce, case-insensitive, max 6 suggestions
- Tags field: comma-separated, autocomplete appends `tag, `
- Save button

### 6. Credential Features
- **Credential form**: service (required), username, password, URL, tags
- **Master password protection toggle**: "Protect with master password"
- **Credential detail view**: field cards for username, password, URL
- **Reveal secret**: master password dialog, decrypts AES-256-GCM
- **Auto-hide**: revealed secret clears after 30 seconds
- **Copy per-field**: username, password (revealed), URL
- **Credential parser**: `service*user*pass*url -#tags` in quick-add

### 7. Merge Entries
- Select ≥2 entries via long-press selection mode
- Tap "Combinar" in selection AppBar
- Text is concatenated: `-- {title} --\n\n{content}\n\n`
- Editable text field before saving
- Saves as new Note entry with combined tags
- Max 20 entries per merge

### 8. Trash
- **Soft delete**: entries moved to trash (not permanently deleted)
- **Trash screen**: accessed via AppBar trash icon or Ctrl+Shift+T
- **Restore**: single entry restore
- **Permanent delete**: single entry or empty all ("Vaciar papelera")
- Confirmation dialogs before any destructive action

### 9. Search
- FTS5 full-text search (SQLite)
- Real-time filtering as user types
- Combines with type/tag filters
- Search bar accessible via Ctrl+F

### 10. Keyboard Shortcuts
| Shortcut | Action |
|----------|--------|
| Ctrl+N | New entry (home only) |
| Ctrl+F | Focus search (home only) |
| Ctrl+, | Settings |
| Ctrl+Shift+T | Trash |
| Esc | Navigate to home |
| Ctrl+E | Edit entry (detail view) |
| Delete | Move to trash (detail view) |
| Ctrl+Left/Right | Previous/next entry |
| Ctrl+Tab | Next entry |
| Ctrl+Shift+Tab | Previous entry |

### 11. Master Password & Security
- **Setup**: password + confirm + optional hint (min 8 chars)
- **Key hierarchy**: MP → Argon2id → KEK, DEK (random 32 bytes), AES-256-GCM per entry
- **Backup codes**: 10 single-use codes shown once (must save externally)
- **Master password gate**: required to view protected entries
- **Change master password**: instant (only re-wraps DEK)
- **Edit hint**: update stored password hint
- **Regenerate backup codes**: invalidates old codes, generates new
- **Delete master password**: warning about unreachable protected entries
- **Auto-lock**: 1/5/15/30 min inactivity or never
- **App lock**: require password on startup
- **Password hint**: optional, stored as plaintext (shown with warning)
- **Rate limiting**: 5 failed MP attempts → 30s lockout; 3 failed backup codes → 60s lockout
- **Recovery flow**: "Forgot password?" → enter backup code → set new MP → new DEK generated

### 12. Tag System
- **Tags**: comma-separated on entries, stored in `entries.tags`
- **Tag colors**: 16-color palette (One Dark Pro inspired), 4×4 grid
- **Color picker**: long-press on tag chip in detail view, 4×4 palette dialog
- **Color propagation**: setting a tag color on one entry propagates to ALL entries with same tag
- **Secure tags**: require master password to view entry content
- **Tag management screen** (Settings → Gestionar etiquetas):
  - Create tags: name + color
  - Rename tags: creates new + deletes old (updates all entries)
  - Delete tags: soft delete (entries keep string, UI hides)
  - Toggle secure: requires master password verification
- **Tag autocomplete**: in entry edit form
- **Tag filter**: via snake FAB (all unique tags listed)

### 13. Settings
- Master password section (status, hint, backup codes count)
- Actions: change MP, edit hint, regenerate codes
- **Security section**: app lock toggle, auto-lock timer selector
- **Theme**: system / dark / light
- **Data**: export to JSON, import from JSON (skip duplicates, shows errors)
- **Tag management**: link to tag management screen
- **Danger zone**: delete master password

### 14. Export/Import
- **Export**: all entries → JSON file via system file picker
- **Import**: JSON file → entries added to vault (existing IDs skipped)
- Progress dialog during operations
- Import result summary: imported count, skipped (duplicates), errors

### 15. Security Architecture (user-facing summary)
- AES-256-GCM encryption for credential secrets
- Argon2id for key derivation
- KEK/DEK wrapping (instant password changes)
- Backup codes with per-code salt + Argon2id hashing
- DEK never stored in plaintext
- Rate limiting against brute force
- Offline-only — no backdoor, no reset, no support

## Existing Documentation

| File | Type | Content |
|------|------|---------|
| `README.md` | Project README | 38 lines: principles, stack, brief MP mention |
| `SECURITY.md` | Security architecture | 161 lines: key hierarchy, backup codes, crypto, rate limits, threats |
| In-app shortcuts sheet | UI | Keyboard shortcuts + quick-add syntax |
| `openspec/specs/master-password-settings/spec.md` | Dev spec | MP setup/change/code regen requirements |
| `openspec/specs/master-password-recovery/spec.md` | Dev spec | Recovery flow requirements |
| `PHASE_2_*.md` | Dev docs | Architecture, design, testing strategy |

## Recommended Format

**Both** — markdown in `docs/` AND in-app help screen:

1. **`docs/manual.md`** — Comprehensive user manual in Spanish (matching app UI language). Serves as:
   - Printable/reference documentation users can keep open
   - Source of truth for any future in-app help features
   - Can be rendered in-app via Markdown viewer

2. **In-app help screen** — A dedicated screen accessible from Settings (and possibly the title tap). Should render the manual content, or at minimum provide key sections (quick-add syntax reference, keyboard shortcuts, security summary).

## Structure Outline

```
docs/manual.md

# Taúl — Manual de Usuario

## 1. Introducción
   - ¿Qué es Taúl? (personal knowledge vault, offline-first)
   - Principios de diseño (minimalismo, velocidad, seguridad)

## 2. Primeros Pasos
   - Instalación
   - Pantalla principal
   - Crear tu primera entrada

## 3. Tipos de Entrada
   - Nota
   - Idea
   - Glosario
   - Credencial

## 4. Escritura Rápida (Quick-Add)
   - Cómo funciona la detección automática
   - Sintaxis inline
     - `!idea` para ideas
     - `Término:definición` para glosario
     - `servicio*usuario*contraseña*url` para credenciales
     - `Título# texto` para títulos explícitos
     - `-#etiqueta` para tags inline
   - Vista previa en vivo
   - Forzar tipo manualmente

## 5. Pantalla Principal
   - Vista de lista vs cuadrícula
   - Tarjetas de entrada
   - Filtros tipo (Snake FAB)
   - Filtros etiqueta (Snake FAB)
   - Búsqueda
   - Estados vacíos
   - Modo selección
   - Expandir inline
   - Combinar entradas

## 6. Vista de Detalle
   - Contenido Markdown
   - Selectable text
   - Tags con color
   - Navegación entre entradas
   - Copiar contenido

## 7. Credenciales
   - Formulario de credencial
   - Protección con contraseña maestra
   - Revelar secreto
   - Auto-ocultar
   - Copiar campos individuales

## 8. Etiquetas
   - Agregar etiquetas al crear/editar
   - Autocompletado de etiquetas
   - Colores de etiqueta
   - Etiquetas seguras
   - Gestión de etiquetas (Settings)

## 9. Editar Entradas
   - Editar desde detalle
   - Campos editables
   - Autocompletado de tags
   - Cambiar tipo

## 10. Combinar Entradas
   - Seleccionar múltiples
   - Editor de combinación
   - Guardar como nota

## 11. Papelera
   - Eliminar entradas (soft delete)
   - Restaurar
   - Eliminación permanente
   - Vaciar papelera

## 12. Búsqueda
   - Búsqueda full-text (FTS5)
   - Sugerencias de búsqueda
   - Filtros combinados

## 13. Contraseña Maestra
   - Qué es y para qué sirve
   - Configuración inicial
   - Pista (advertencia de texto plano)
   - Códigos de respaldo
   - Cambiar contraseña
   - Recuperación por código de respaldo
   - Eliminar contraseña maestra (ADVERTENCIA)
   - Bloqueo general al inicio
   - Bloqueo automático por inactividad

## 14. Seguridad (para usuarios)
   - Cifrado AES-256-GCM
   - Jerarquía de claves KEK/DEK
   - Argon2id
   - Límites de intentos
   - Sin backdoor

## 15. Configuración
   - Contraseña Maestra
   - Seguridad (bloqueo)
   - Tema
   - Exportar/Importar datos
   - Gestión de etiquetas

## 16. Atajos de Teclado
   - Tabla completa de atajos

## 17. Preguntas Frecuentes
   - ¿Dónde se guardan mis datos?
   - ¿Qué pasa si olvido mi contraseña maestra?
   - ¿Puedo recuperar una entrada eliminada?
   - ¿Cómo migro mis datos a otro equipo?
```

## Risks

- **Outdated documentation**: manual must reference specific UI labels and behaviors that could change. A review process is needed on feature changes.
- **Security warnings**: the manual MUST clearly communicate risks around password hints (plaintext), backup codes (shown once), and master password deletion (data loss).
- **Language mismatch**: app UI is in Spanish but code is in English. The manual should match the app's UI language (Spanish).
- **Scope creep**: the manual should not become a developer reference — keep it user-focused.

## Ready for Proposal

Yes — proceed with Proposal phase. The exploration is complete and the scope is well-defined. Recommend starting with the `docs/manual.md` file, then building the in-app help screen as a follow-up.
