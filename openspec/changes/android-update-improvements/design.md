# Design: Android Update Improvements

## Technical Approach

Enhance `UpdateService` and its callers to validate APK integrity, clean up temporary files, notify users of success, and provide more specific error feedback.

## Architecture Decisions

### Decision: Hash Validation Strategy

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Validate hash before installation | Catches corruption early, blocks install on mismatch | **Chosen** |
| Validate hash after installation | Too late — installer already ran | Rejected |
| Skip validation entirely | Insecure, vulnerable to tampering | Rejected |

**Rationale**: Validating before installation prevents executing a corrupted or tampered APK. The hash is computed on the downloaded file and compared against `manifest.sha256`. If the manifest doesn't contain `sha256` (backward compatibility with older releases), validation is skipped with a warning log.

**Contract (matches specs.md — throws on mismatch, does NOT return bool)**:

```dart
/// Validates SHA-256 of [filePath] against [expectedHash].
/// Skips validation when [expectedHash] is null (backward compatibility).
/// Throws [HashMismatchException] on mismatch, [FileSystemException] when
/// the file does not exist or is unreadable.
Future<void> validateHash(String filePath, String? expectedHash);
```

**Hash primitive**: use `Sha256` from the already-present `cryptography` package (`package:cryptography/cryptography.dart`); compute via `await Sha256().hash(data)` and compare hex digests case-insensitively. No new dependency.

### Decision: Cleanup Timing (R3-002 correction)

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Cleanup in `finally` block | May delete before installer reads file | Rejected |
| Cleanup after `installUpdate()` returns | Race on Android — PackageInstaller reads APK asynchronously | **Rejected (R3-002)** |
| Pre-download stale cleanup + let OS handle cache | Avoids TOCTOU race; cache dir is OS-managed | **Chosen (R3-002)** |

**Rationale**: On Android, `installUpdate()` opens the APK via Intent and returns immediately (`MainActivity.kt:41 → result.success(true)`). The system PackageInstaller reads the file asynchronously via content URI **after** our process returns. Deleting the APK immediately after `installUpdate()` causes a TOCTOU race: "problem parsing the package" with no file to retry.

On Windows, the Inno Setup installer kills our process via `taskkill`, so a post-launch delete wouldn't run reliably either.

**New strategy**: Clean up stale installers **pre-download** (before writing a new file to the same path). Files live in `getTemporaryDirectory()` which on Android maps to `getCacheDir()` — the OS may reclaim them at any time. No explicit post-install cleanup is needed on any platform.

`cleanup()` remains as a public method for manual/forced cleanup but is no longer called automatically after `installUpdate()`.

### Decision: Error Granularity

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Generic "update failed" message | Simple, hides internals | Rejected |
| Specific messages per error type | Better UX, helps debugging | **Chosen** |
| Full technical details in UI | Exposes internals, overwhelming | Rejected |

**Rationale**: Users benefit from knowing *why* an update failed (no network? hash mismatch? install blocked?). Technical details go to logs only.

### Decision: Success Notification

| Option | Tradeoff | Decision |
|--------|----------|----------|
| No notification (silent) | Unobtrusive, user unsure if it worked | Rejected |
| SnackBar with "Update installed" | Simple, non-blocking | **Chosen** |
| Dialog requiring dismiss | Disruptive, blocks flow | Rejected |

**Rationale**: A brief SnackBar confirms the update was applied. On Android, the system installer dialog is already visible, so our SnackBar appears after the user completes the system flow.

## Data Flow

```
_downloadAndInstall(context, service, manifest)
  │
  ├─ Show "Descargando actualización..." SnackBar
  │
  ├─ path = await service.downloadUpdate(url)
  │   ├─ [NEW] Delete stale installer at destination (best-effort, pre-download)
  │   ├─ Downloads to temp directory
  │   └─ Returns file path
  │
  ├─ [NEW] if (Platform.isAndroid) — validateHash gated to Android only (R3-001)
  │   ├─ If sha256 is null → skip validation
  │   ├─ Compute SHA-256 of downloaded file (cryptography package)
  │   └─ Compare with manifest.sha256 (case-insensitive hex)
  │
  ├─ [NEW] If validateHash throws HashMismatchException:
  │   ├─ Delete downloaded file (best-effort, errors logged)
  │   └─ Rethrow so caller maps to "Archivo corrupto"
  │
  ├─ await service.installUpdate(path)
  │   ├─ Windows: launch installer
  │   └─ Android: open APK via FileProvider
  │
  │   ✗ NO post-install cleanup (R3-002: race with PackageInstaller on Android;
  │     on Windows installer kills process via taskkill so delete wouldn't run)
  │   Stale files are cleaned up pre-download instead.
  │
  ├─ [NEW] Show "Actualización a v{manifest.version} instalada" SnackBar
  │
  └─ Catch errors (mapped to user messages):
      ├─ HashMismatchException → "Archivo corrupto. Intentá de nuevo."
      ├─ SocketException / TimeoutException → "Sin conexión. Verificá tu red."
      ├─ FileSystemException → "Error al guardar. ¿Espacio insuficiente?"
      └─ Generic → "No se pudo completar la actualización."
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/core/auto_updater.dart` | Modify | Add `sha256` to `UpdateManifest`, add `validateHash()`, add `cleanup()`, add specific exception types, add pre-download stale cleanup in `downloadUpdate()` |
| `lib/app.dart` | Modify | Gate `validateHash` to Android only (R3-001), remove post-install `cleanup()` (R3-002), show success SnackBar, handle specific exceptions |
| `lib/ui/screens/about_screen.dart` | Modify | Same changes as `app.dart` (parallel update flow) |
| `.github/workflows/release.yml` | Modify | Compute SHA-256 of APK and emit in manifest.json (R3-001) |

No new files created. No files deleted.

## Interfaces / Contracts

### New Exceptions

```dart
/// Thrown when downloaded APK hash doesn't match manifest.
class HashMismatchException implements Exception {
  final String expected;
  final String actual;
  const HashMismatchException(this.expected, this.actual);
  @override
  String toString() => 'Hash mismatch: expected $expected, got $actual';
}
```

### Updated Manifest Model

```dart
class UpdateManifest {
  final String version;
  final String url;
  final String? androidUrl;
  final String? notes;
  final String? sha256;  // NEW — optional for backward compatibility
  // ... existing constructor and fromJson
}
```

### New Service Methods

```dart
/// Validates SHA-256 hash of downloaded file against manifest.
/// Throws HashMismatchException on mismatch; skips when expectedHash is null.
Future<void> validateHash(String filePath, String? expectedHash);

/// Deletes temporary file after installation. Idempotent — no-op when the
/// file does not exist. Callers MUST wrap in try/catch and log failures;
/// cleanup errors are never user-facing.
Future<void> cleanup(String filePath);
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `_isNewer` version comparison (existing) | No changes |
| Unit | `validateHash` with matching hash | Mock file, provide matching SHA-256 |
| Unit | `validateHash` with mismatching hash | Verify `HashMismatchException` thrown |
| Unit | `validateHash` with null hash (backward compat) | Verify returns true without computing |
| Unit | `cleanup` deletes file | Create temp file, call cleanup, verify deleted |
| Unit | `cleanup` with non-existent file | Verify no exception thrown (idempotent) |
| Unit | `UpdateManifest.fromJson` with sha256 field | Verify parsing |
| Unit | `UpdateManifest.fromJson` without sha256 field | Verify sha256 is null (backward compat) |

## Migration / Rollout

No migration required. Changes are backward-compatible:
- `sha256` in manifest is optional — old releases without it still work
- New error types extend `Exception` — existing catch blocks still catch them
- Success SnackBar is additive — no existing behavior changed

## Open Questions

- [x] Should we add hash validation for Windows installer too? **Decided**: No — out of scope for this change, Android only. Future follow-up.
- [x] Should the success SnackBar include the new version number? **Decided**: Yes — "Actualización a v1.5.2 instalada".
