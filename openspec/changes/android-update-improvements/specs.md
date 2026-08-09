# Specs: Android Update Improvements

## Requirement: APK Hash Validation (R3-001 gate)

The system SHALL validate the SHA-256 hash of downloaded APK files against the hash provided in the update manifest before attempting installation. Validation is **Android-only** — the manifest's `sha256` field covers the APK; Windows installer hash validation is a separate future scope.

### Scenario: Valid hash

**Given** a manifest with `sha256: "abc123..."` and a downloaded APK whose SHA-256 is `"abc123..."`
**When** `validateHash()` is called
**Then** it SHALL complete without throwing

### Scenario: Mismatched hash

**Given** a manifest with `sha256: "abc123..."` and a downloaded APK whose SHA-256 is `"def456..."`
**When** `validateHash()` is called
**Then** it SHALL throw `HashMismatchException`

### Scenario: No hash in manifest (backward compatibility)

**Given** a manifest without `sha256` field (null)
**When** `validateHash()` is called
**Then** it SHALL complete without throwing and without computing any hash

### Scenario: Downloaded file deleted before validation

**Given** a manifest with `sha256: "abc123..."` and a file path that doesn't exist
**When** `validateHash()` is called
**Then** it SHALL throw `FileSystemException`

---

## Requirement: Post-Install Cleanup (R3-002 correction)

The system SHALL clean up stale installers **before download**, not after installation.

### Rationale (R3-002)

On Android, `installUpdate()` returns immediately after firing the Intent. The system PackageInstaller reads the APK asynchronously — deleting it right after `installUpdate()` causes a TOCTOU race ("problem parsing the package"). On Windows, the installer kills our process via `taskkill`, so a post-launch delete wouldn't run reliably. Files live in `getTemporaryDirectory()` (Android's `getCacheDir()`), which the OS manages.

### Scenario: Stale installer removed before new download

**Given** a previous interrupted download left a file at the destination path
**When** `downloadUpdate()` is called with a URL that maps to the same filename
**Then** the stale file SHALL be deleted before the new download begins (best-effort)

### Scenario: No file to clean up

**Given** no previous file exists at the destination path
**When** `downloadUpdate()` is called
**Then** it SHALL proceed with the download without error

### Scenario: Cleanup failure is non-fatal

**Given** the stale file exists but cannot be deleted (e.g., permissions)
**When** `downloadUpdate()` attempts cleanup
**Then** the exception SHALL be caught and the download SHALL proceed

---

### Scenario: File already deleted (cleanup() standalone)

**Given** a file path that doesn't exist
**When** `cleanup()` is called directly
**Then** it SHALL complete without error (idempotent)

### Scenario: Cleanup failure does not block user

**Given** `cleanup()` throws an exception
**When** the exception propagates
**Then** it SHALL be caught and logged, NOT shown to the user (non-critical)

---

## Requirement: Success Notification

The system SHALL display a confirmation message to the user after a successful update installation.

### Scenario: Android APK installation

**Given** the user initiated an update on Android
**When** `installUpdate()` completes successfully
**Then** a SnackBar SHALL appear with text containing "Actualización" and the new version number

### Scenario: Windows installer launch

**Given** the user initiated an update on Windows
**When** `installUpdate()` launches the installer
**Then** a SnackBar SHALL appear with text indicating the installer was launched

---

## Requirement: Specific Error Messages

The system SHALL display user-friendly error messages that indicate the type of failure.

### Scenario: Network error during download

**Given** the device has no internet connection
**When** `downloadUpdate()` is called
**Then** a SnackBar SHALL appear with text indicating a network problem (e.g., "Sin conexión")

### Scenario: Hash mismatch

**Given** a downloaded APK with incorrect hash
**When** `validateHash()` throws `HashMismatchException`
**Then** a SnackBar SHALL appear with text indicating the file may be corrupt

### Scenario: File system error

**Given** insufficient storage space
**When** `downloadUpdate()` fails with `FileSystemException`
**Then** a SnackBar SHALL appear with text indicating a storage problem

### Scenario: Generic error

**Given** an unexpected error
**When** any update step fails
**Then** a SnackBar SHALL appear with a generic "No se pudo completar" message

---

## Requirement: Manifest Compatibility

The system SHALL accept manifests both with and without the `sha256` field.

### Scenario: Manifest with sha256

**Given** `{"version": "1.5.2", "url": "...", "sha256": "abc123..."}`
**When** parsed by `UpdateManifest.fromJson()`
**Then** `sha256` SHALL be `"abc123..."`

### Scenario: Manifest without sha256

**Given** `{"version": "1.5.2", "url": "..."}`
**When** parsed by `UpdateManifest.fromJson()`
**Then** `sha256` SHALL be `null`
