# Tasks: Android Update Improvements

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~150 |
| 400-line budget risk | Low |
| Chained PRs recommended | No |
| Delivery strategy | single-pr |

## Phase 1: Domain Layer — Manifest & Service

- [x] 1.1 Add `sha256` field to `UpdateManifest` — update constructor, `fromJson`, and `downloadUrl` getter; `sha256` is nullable for backward compatibility
- [x] 1.2 Add `HashMismatchException` class to `auto_updater.dart` — with `expected` and `actual` fields
- [x] 1.3 Implement `UpdateService.validateHash(String filePath, String? expectedHash)` — compute SHA-256 (via `cryptography` package `Sha256`), compare with expected (case-insensitive hex), **throw** `HashMismatchException` on mismatch; **skip without computing** when expectedHash is null; throw `FileSystemException` if file missing
- [x] 1.4 Implement `UpdateService.cleanup(String filePath)` — delete file if exists, no-op if absent (idempotent); failures propagate so callers can log (never user-facing)
- [x] 1.5 Write unit tests for `validateHash` — valid hash, mismatched hash, null hash (backward compat), missing file
- [x] 1.6 Write unit tests for `cleanup` — file exists, file already deleted

## Phase 2: UI Layer — Error Handling & Notifications

- [x] 2.1 Update `_downloadAndInstall` in `app.dart` — add `validateHash` step after download (throws on mismatch); wrap `cleanup` in its own try/catch that only logs (never shows user); show success SnackBar "Actualización a v{version} instalada"
- [x] 2.2 Update `_downloadAndInstall` in `about_screen.dart` — same changes as app.dart (validateHash, silent cleanup with log, success SnackBar with version)
- [x] 2.3 Add specific error handling — catch `HashMismatchException`, `SocketException`, `TimeoutException`, `FileSystemException` separately with user-friendly messages
- [x] 2.4 Write unit tests for error message selection — verify correct message per exception type

## Phase 3: Verification

- [x] 3.1 Run `dart analyze` — fix all warnings
- [x] 3.2 Run `flutter test` — all tests pass
- [ ] 3.3 Manual test: verify hash validation works with a test manifest
- [ ] 3.4 Manual test: verify cleanup deletes APK after install
