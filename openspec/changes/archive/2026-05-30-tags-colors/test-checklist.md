# Checklist Manual — Tags con Colores

Corré la app y probá cada item. Marcá con ✅ cuando funcione.

---

## 📦 Preparación

- [ ] La app compila y abre sin errores
- [ ] Las entradas existentes se muestran sin color (gris por defecto)

---

## 🔵 Indicadores Visuales

### Grilla (home con varias entradas)

- [ ] Entrada **sin tags** → no muestra barra de acento
- [ ] Entrada con **1 tag sin color** → barra gris (`#9E9E9E`)
- [ ] Entrada con **1 tag con color** → barra de 4px en ese color
- [ ] Entrada con **3 tags con colores distintos** → barra en el color mezclado (promedio HSL)

### Lista (home, una sola columna, pantalla angosta)

- [ ] Entrada sin tags → no muestra puntito
- [ ] Entrada con 1 tag sin color → puntito gris
- [ ] Entrada con 1 tag con color → puntito de 8px en ese color
- [ ] Entrada con múltiples tags → puntito en el color mezclado

### Detalle de entrada

- [ ] Entrada sin tags → sin barra de acento en el cuerpo
- [ ] Entrada con tags → barra de 4px en el borde izquierdo del cuerpo
- [ ] Entrada sin tags → chips de tag sin color de fondo
- [ ] Entrada con tags con color → chips de tag con fondo del color asignado
- [ ] Cada chip muestra su color individual (NO el mezclado)

### Filtro de tags (home)

- [ ] Tag sin color asignado → chip sin fondo
- [ ] Tag con color asignado → chip con fondo de ese color
- [ ] Si borrás el color de un tag, el chip vuelve a sin fondo

---

## 🎨 Palette Picker

### Abrir el selector

- [ ] Long-press en un chip de tag en la vista de detalle → se abre el selector
- [ ] Muestra **16 círculos** de color en grilla 4×4
- [ ] Si el tag ya tiene color, ese color aparece **seleccionado** (checkmark)

### Seleccionar color

- [ ] Tocar un color → se cierra el selector
- [ ] El chip cambia inmediatamente al nuevo color
- [ ] La barra de acento se actualiza con el nuevo color mezclado
- [ ] Si hay múltiples tags, la barra refleja la nueva mezcla

### Persistencia

- [ ] Cerrar y volver a abrir la entrada → los colores de los tags se mantienen
- [ ] Cerrar y reiniciar la app → los colores persisten

### Sin color

- [ ] Si el tag nunca tuvo color asignado, el chip se ve sin fondo
- [ ] El indicador (barra/punto) se ve en gris

---

## 🔄 Edge Cases

- [ ] Entrada **creada desde quick-add** con `-#tag` → el tag aparece sin color (ok)
- [ ] Entrada **editada** → al cambiar tags, los colores existentes se mantienen
- [ ] **Reiniciar app** con datos nuevos → todo funciona (migración v6 ejecutada)
- [ ] Varias entradas con el **mismo tag** → cada una puede tener un color distinto (per-entry)
- [ ] **Papelera**: ver entry en papelera → no debería mostrar indicadores de color
- [ ] **Scroll** en home → los colores no titilan ni se renderizan mal

---

## 🐛 Bugs Conocidos (Preexistentes, no de este cambio)

- [ ] En algunos casos el login puede pedir autenticación al crear credenciales
- [ ] Empty title en CreateEntry no da error (nunca lo hizo)
