# Proposal: Android Update Improvements

## Intent

Improve the reliability and UX of the Android auto-update flow by adding APK hash validation, post-install cleanup, success notification, and more specific error messages.

## Scope

**Included:**
- SHA-256 hash validation for downloaded APKs
- Post-install APK cleanup (delete temp file after installation)
- Success notification (SnackBar) after successful installation
- More specific error messages (network, hash mismatch, install failed)

**Excluded:**
- FileProvider path configuration (already correct — `getTemporaryDirectory()` maps to `getCacheDir()`, matching `<cache-path>` in `file_paths.xml`)
- Windows installer changes (out of scope)
- Rollback mechanism (future enhancement)

## Affected Layers

- **domain/**: `UpdateManifest` (add `sha256` field), `UpdateService` (add hash validation, cleanup, improved errors)
- **infrastructure/**: No changes
- **ui/**: `app.dart`, `about_screen.dart` (show success SnackBar, handle specific errors)
- **android/**: No changes needed

## Rollback Plan

All changes are additive. Reverting the branch restores previous behavior. No database migrations, no schema changes, no breaking API changes.

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Hash validation fails for old releases without sha256 in manifest | Make sha256 optional; skip validation if not present |
| Cleanup deletes APK before installer finishes (Android) | Cleanup happens after `installUpdate()` returns; Android installer reads the file before our process returns |
| Specific error messages expose internal details | Use user-friendly messages, log technical details only |
