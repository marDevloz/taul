# Taúl

**Un almacén personal mínimo, rápido, seguro y soberano.**

Taúl es una aplicación local y minimalista diseñada para almacenar información personal de forma inmediata y recuperarla en segundos.

> Guardar algo importante en 3 segundos y encontrarlo en 1.

## Principios

- Minimalismo funcional
- Baja fricción
- Seguridad por defecto
- Offline-first
- Infraestructura cero
- Rapidez sobre complejidad
- Control absoluto del usuario

## Stack

- **Flutter** — multiplataforma (Windows, Linux, Android, iOS)
- **SQLite FTS5** — búsqueda instantánea full-text
- **AES-256-GCM + Argon2id** — cifrado de credenciales
- **go_router** — navegación
- **flutter_quill** — editor de texto enriquecido
- **Drift** — ORM para SQLite

## Tipos de entrada

| Tipo     | Sintaxis                  | Descripción                              |
| -------- | ------------------------- | ---------------------------------------- |
| Nota     | —                         | Texto enriquecido libre                  |
| Idea     | `!idea`                   | Destacada visualmente, se saca el `!`    |
| Glosario | `término:definición`      | Término en negrita, definición en cursiva|
| Credencial | `servicio*user*pass`    | Cifrada, solo visible con contraseña maestra |
| **Tarea**  | `- [ ] tarea` o `[ ] pendiente` | Lista de tareas estilo checkbox, detectada automáticamente |

**Auto-detección**: el tipo se detecta desde el contenido al escribir. No se activa si hay espacio después del marcador (`! texto` no es idea, `* texto` no es credencial, `término : def` no es glosario).

**Título inline**: `Título# contenido` — todo antes de `# ` se convierte en el título.

**Tags inline**: `-#etiqueta` en el contenido agrega una etiqueta.

## Sincronización Peer-to-Peer por Wi-Fi Local 🔄

Taúl incluye un protocolo de sincronización **P2P seguro** que permite sincronizar tus datos entre dispositivos (PC ↔ Móvil) sin servidores intermedios ni infraestructura externa:

- **Comunicación directa**: Los dispositivos se conectan entre sí a través de tu red Wi-Fi local usando HTTPS
- **Certificados X.509 autofirmados**: Cada dispositivo genera sus propios certificados RSA 2048-bit para cifrado TLS
- **Emparejamiento por QR**: Escanea un código QR o ingresa un código de emparejamiento para conectar dispositivos
- **TOFU (Trust On First Use)**: La primera conexión establece la confianza, las siguientes la validan automáticamente
- **Cero fugas de datos**: Las claves de desencriptado (DEK) **nunca salen del dispositivo**. Solo viajan los blobs cifrados por la red
- **Infraestructura cero**: No requiere configuración de servidores, puertos, ni servicios en la nube

> **Nota**: La sincronización funciona completamente offline entre dispositivos en la misma red local. Tus datos nunca tocan servidores externos.

## Funcionalidades

- **Creación rápida**: botón + o Ctrl+N → formulario con editor rich text, título, tags y selector de tipo.
- **Editor de texto enriquecido**: negrita, cursiva para notas y glosarios.
- **Búsqueda en tiempo real**: FTS5, resultados mientras escribís, coincidencias parciales.
- **Filtros**: por tipo (nota/idea/glosario/credencial) y por etiqueta, desde FABs expansibles.
- **Etiquetas**: con colores asignables globalmente (long-press → paleta), etiquetas seguras que requieren contraseña maestra.
- **Combinar entradas**: selección múltiple → fusionar contenido y etiquetas en una nueva entrada.
- **Papelera**: entradas eliminadas con opción de restaurar o vaciar.
- **Exportar/Importar**: formato JSON completo.
- **Atajos de teclado**: navegación completa sin mouse (Ctrl+N/F/E/,/Shift+T, ←/→, Tab).

## Seguridad

### Protección con Contraseña Maestra

Las credenciales se protegen con una contraseña maestra:

- **Cifrado transparente**: una vez desbloqueado, el cifrado/descifrado ocurre silenciosamente usando una clave de cifrado de datos (DEK) en caché.
- **Recuperación offline**: 10 códigos de respaldo de un solo uso (hasheados con Argon2id) permiten la recuperación sin conexión.
- **KEK/DEK wrapping**: cambiar la contraseña maestra es instantáneo — no requiere recifrado de entradas.
- **Bloqueo automático**: por inactividad (1/5/15/30 min) o al iniciar la app.
- **Etiquetas seguras**: las entradas con etiquetas marcadas como seguras también se ocultan tras la contraseña maestra.

### Arquitectura Criptográfica de Grado Empresarial 🛡️

Taúl implementa un sistema de seguridad avanzado diseñado para proteger tus datos incluso en escenarios adversos:

- **Argon2id optimizado**: Parámetros configurados (memory: 65MB, iterations: 3, parallelism: 1) para máximo equilibrio entre seguridad anti-fuerza bruta y rendimiento en móviles
- **AES-256-GCM**: Cifrado autenticado para envolver las claves DEK, garantizando integridad y confidencialidad
- **Códigos de respaldo verificados**: El sistema genera 10 códigos únicos, deriva una clave específica para cada uno con sal independiente, y realiza una verificación round-trip antes de mostrarlos al usuario
- **Aislamiento DEK**: Las claves de desencriptado nunca salen del dispositivo ni se transmiten por la red, incluso durante la sincronización

Ver [SECURITY.md](SECURITY.md) para la arquitectura detallada.
