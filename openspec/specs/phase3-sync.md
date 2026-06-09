# Delta Spec: Phase 3 — Device-to-Device Sync

**Spec ID:** phase3-sync
**Version:** 1.0
**Status:** Implemented (Archived)
**Created:** 2026-06-08
**Related:** [proposal: sdd/phase3-sync/proposal](engram://#444) · [exploration: sdd/phase3-sync/explore](engram://#442)

---

## 1. SYNC-PROTOCOL-01: HTTPS Sync Server

**ID:** SYNC-PROTOCOL-01
**Title:** HTTPS Sync Server — Shelf-based local sync endpoint

### User Story
As a Taúl user, I want my device to host a local HTTPS server that another device can connect to for sync, so that we can exchange entries securely over the local network.

### System Requirement
The app must run an HTTPS server using `shelf` + `shelf_io` on a random available port, bound to `0.0.0.0`, serving a single POST `/sync` endpoint with a self-signed TLS certificate.

### Scenarios

**GIVEN** the vault is UNLOCKED
**WHEN** the user taps "Start Sync" on Device A
**THEN** the app generates a self-signed X.509 certificate (RSA 2048-bit, SHA-256), starts an HTTPS server on a random port, and displays the device's local IP + port as a QR code.

**GIVEN** the server is running on Device A
**WHEN** Device B sends a valid POST `/sync` request with a correct pairing code
**THEN** Device A accepts the request and returns the sync response with modified entries since `lastSyncAt`.

**GIVEN** the server is running on Device A
**WHEN** Device B sends a POST `/sync` request with an incorrect pairing code
**THEN** Device A returns HTTP 401 Unauthorized and logs the failed attempt.

**GIVEN** the vault is LOCKED
**WHEN** the user taps "Start Sync"
**THEN** the app shows an error message: "Unlock the vault first to sync" and does not start the server.

**GIVEN** the server is already running
**WHEN** the user taps "Start Sync" again
**THEN** the app returns the same QR code and server instance (idempotent).

**GIVEN** the server is running
**WHEN** no sync request arrives within 5 minutes
**THEN** the server shuts down automatically and the UI returns to idle state.

### Acceptance Criteria
- [ ] HTTPS server starts on random port (range 49152–65535)
- [ ] Self-signed cert is generated on first use, stored in app documents dir as `sync_cert.pem` + `sync_key.pem`
- [ ] Cert is reused across sessions (regenerated only if files are missing or corrupt)
- [ ] POST `/sync` endpoint accepts JSON body, validates pairing code, returns 401 on failure
- [ ] Server uses `SecurityContext` with the self-signed cert for TLS
- [ ] Server auto-shutdowns after 5 minutes of inactivity
- [ ] Vault LOCKED state blocks server start

### Edge Cases
- Port already in use: retry with next port in range, fail after 5 attempts
- Cert generation failure: show error, do not start server
- Server crash: auto-restart once, then show error
- Multiple concurrent requests: reject with HTTP 429 (one sync at a time)

### Dependencies
- None (standalone capability)

---

## 2. SYNC-PROTOCOL-02: HTTPS Sync Client

**ID:** SYNC-PROTOCOL-02
**Title:** HTTPS Sync Client — Connect and exchange entries

### User Story
As a Taúl user, I want to connect to another device's sync server and exchange modified entries, so that my vault stays in sync.

### System Requirement
The app must implement an HTTP client using the `http` package that connects to a remote device's HTTPS server, sends the local device ID + last sync timestamp + modified entries, and receives the remote's modified entries.

### Scenarios

**GIVEN** Device B has scanned Device A's QR code
**WHEN** Device B connects to Device A's server
**THEN** Device B sends a POST `/sync` with body `{deviceId, lastSyncAt, entries: [...]}` and a pairing code header `X-Pairing-Code`.

**GIVEN** Device A responds with HTTP 200 and a list of entries
**WHEN** Device B processes the response
**THEN** Device B upserts entries where `remote.updatedAt > local.updatedAt` (or local doesn't exist), stores `lastSyncAt` as the server's current timestamp, and reports success.

**GIVEN** Device A responds with HTTP 401
**WHEN** Device B processes the response
**THEN** Device B shows "Invalid pairing code" and prompts the user to re-enter.

**GIVEN** Device A responds with HTTP 409 (conflict)
**WHEN** Device B processes the response
**THEN** Device B stores conflict records in the `conflicts` table and shows the conflict count.

**GIVEN** the connection times out (10 seconds)
**WHEN** the request fails
**THEN** Device B shows "Connection failed — is the other device's sync server running?" and returns to idle.

### Acceptance Criteria
- [ ] Client sends `deviceId` (UUID from SharedPreferences), `lastSyncAt` (ISO8601), and `entries` (JSON array)
- [ ] Client validates TLS certificate against pinned SHA-256 fingerprint from pairing
- [ ] Client uses 10-second connection timeout, 30-second read timeout
- [ ] Client handles HTTP 200 (success), 401 (bad code), 409 (conflict), 429 (busy), 5xx (server error)
- [ ] Entries sent are only those with `updatedAt > lastSyncAt` for this peer
- [ ] Response entries are upserted into local DB

### Edge Cases
- Server disappears mid-sync: show "Sync interrupted", no data loss (entries are versioned)
- Both devices send same entry: both copies are stored, conflict record created
- Large payload (1000+ entries): send in chunks of 100 entries per request

### Dependencies
- SYNC-PROTOCOL-01 (server must exist for client to connect to)
- SYNC-DB-01 (conflicts table for 409 handling)
- SYNC-SECURITY-01 (TLS certificate validation)

---

## 3. SYNC-PAIR-01: QR Code Pairing

**ID:** SYNC-PAIR-01
**Title:** QR Code Pairing — Device discovery via QR scan

### User Story
As a Taúl user, I want to pair with another device by scanning a QR code, so that I can start syncing without manually entering IP addresses.

### System Requirement
Device A generates a QR code containing its sync server URL (`https://<ip>:<port>`) and a 6-digit pairing code displayed on screen. Device B scans the QR code and enters the 6-digit code to complete pairing.

### Scenarios

**GIVEN** Device A's sync server is running
**WHEN** the user views the sync screen on Device A
**THEN** a QR code is displayed showing `https://192.168.1.x:xxxxx` and a 6-digit numeric code (e.g., `482917`) is displayed below it.

**GIVEN** Device B scans Device A's QR code
**WHEN** the QR code is decoded to `https://192.168.1.x:xxxxx`
**THEN** Device B prompts the user to enter the 6-digit code shown on Device A.

**GIVEN** Device B enters the correct 6-digit code
**WHEN** Device B sends the sync request with the code
**THEN** pairing succeeds and sync proceeds.

**GIVEN** Device B enters an incorrect 6-digit code
**WHEN** Device B sends the sync request
**THEN** Device B shows "Invalid code — try again" with max 3 attempts before lockout.

**GIVEN** the user is on Android and uses `mobile_scanner`
**WHEN** the QR code is in frame
**THEN** scanning is automatic, no tap needed.

**GIVEN** the user is on desktop and uses a built-in camera or screen share
**WHEN** the QR code is displayed by Device A
**THEN** Device B's desktop app can scan or the user can manually enter the URL.

### Acceptance Criteria
- [ ] QR code encodes `https://<local-ip>:<port>` in standard QR format
- [ ] 6-digit code is cryptographically random (from `dart:math` SecureRandom)
- [ ] Code is valid for the duration of the sync session (max 5 minutes)
- [ ] After 3 failed code attempts, the session is invalidated and a new code is generated
- [ ] `mobile_scanner` is used on Android for QR scanning
- [ ] On desktop, manual URL entry is supported as fallback

### Edge Cases
- Camera permission denied on Android: show fallback manual entry
- IP changes mid-pairing (DHCP renewal): server re-binds, QR needs refresh
- QR code too small/far: zoom or use manual entry

### Dependencies
- SYNC-PROTOCOL-01 (server provides the URL for the QR code)

---

## 4. SYNC-DELTA-01: Delta Sync with lastSyncAt

**ID:** SYNC-DELTA-01
**Title:** Delta Sync — Only exchange modified entries since last sync

### User Story
As a Taúl user, I want sync to only transfer entries that have changed since the last sync, so that syncing is fast and efficient.

### System Requirement
Each device pair maintains a `lastSyncAt` timestamp. On sync, a device sends only entries where `updatedAt > lastSyncAt` for that specific peer. The remote device does the same. After a successful sync, both devices update their `lastSyncAt` to the current server timestamp.

### Scenarios

**GIVEN** Device A last synced with Device B at `2026-06-08T10:00:00Z`
**WHEN** Device A initiates a new sync with Device B
**THEN** Device A sends only entries where `updatedAt > 2026-06-08T10:00:00Z`.

**GIVEN** Device B has not synced with Device A before
**WHEN** Device B initiates a sync
**THEN** Device B sends ALL non-deleted entries (first sync is a full dump).

**GIVEN** a sync completes successfully
**WHEN** the response timestamp is `2026-06-08T12:00:00Z`
**THEN** both devices store `lastSyncAt = 2026-06-08T12:00:00Z` for this peer pair.

**GIVEN** Device A has entries E1 (updated at 10:05) and E2 (updated at 09:50)
**WHEN** lastSyncAt is `10:00:00`
**THEN** only E1 is included in the sync payload.

### Acceptance Criteria
- [ ] `lastSyncAt` is stored per-device-pair in SharedPreferences key `sync_last_<peerDeviceId>`
- [ ] First sync (no `lastSyncAt`) sends all non-deleted entries
- [ ] Subsequent syncs send only entries with `updatedAt > lastSyncAt`
- [ ] Soft-deleted entries (`deletedAt != null`) are included in sync with their `deletedAt` preserved
- [ ] After sync, `lastSyncAt` is updated to the server's response timestamp
- [ ] Sync payload includes: id, type, title, content, metadata, tags, encryptedSecret, cipherNonce, cipherTag, requiresAuth, createdAt, updatedAt, version, deletedAt, completedAt

### Edge Cases
- Clock skew between devices: use server timestamp as authoritative `lastSyncAt`
- Entry modified during sync: will be included in next sync (acceptable)
- Deleted entry sync: soft-delete is transmitted, not hard-delete

### Dependencies
- SYNC-PROTOCOL-01/02 (server and client implement the exchange)

---

## 5. SYNC-CONFLICT-01: Conflict Detection

**ID:** SYNC-CONFLICT-01
**Title:** Conflict Detection — Identify entries modified on both devices

### User Story
As a Taúl user, I want the system to detect when the same entry has been modified on both devices since the last sync, so that I can resolve the conflict manually.

### System Requirement
When receiving entries from a remote device, compare each entry by ID. If both local and remote versions have `updatedAt > lastSyncAt`, a conflict is recorded in the `conflicts` table with both versions.

### Scenarios

**GIVEN** local entry E1 has `updatedAt = 2026-06-08T11:00:00` and `lastSyncAt = 10:00:00`
**WHEN** remote entry E1 arrives with `updatedAt = 2026-06-08T10:30:00`
**THEN** no conflict — remote is older, local is kept. (Wait, both are after lastSyncAt. Need to re-check.)

Let me re-specify:

**GIVEN** local entry E1 has `updatedAt = 2026-06-08T11:00:00` and `lastSyncAt = 10:00:00`
**WHEN** remote entry E1 arrives with `updatedAt = 2026-06-08T10:30:00`
**THEN** BOTH are newer than lastSyncAt — a conflict is recorded with `localVersion` = local E1 and `remoteVersion` = remote E1.

**GIVEN** local entry E1 has `updatedAt = 2026-06-08T09:30:00` and `lastSyncAt = 10:00:00`
**WHEN** remote entry E1 arrives with `updatedAt = 2026-06-08T10:30:00`
**THEN** only remote was modified since lastSyncAt — remote version replaces local (no conflict).

**GIVEN** local entry E1 has `updatedAt = 2026-06-08T11:00:00` and `lastSyncAt = 10:00:00`
**WHEN** remote entry E1 does NOT exist (was deleted remotely)
**THEN** no conflict — local version is kept, remote deletion is ignored (or handled as conflict per policy).

**GIVEN** remote entry E2 does NOT exist locally and `lastSyncAt` was set
**WHEN** remote entry E2 arrives with `updatedAt > lastSyncAt`
**THEN** E2 is inserted locally (no conflict — new entry from remote).

### Acceptance Criteria
- [ ] Conflict detection compares entry ID + both `updatedAt` vs `lastSyncAt`
- [ ] Conflict is created ONLY when both local AND remote `updatedAt > lastSyncAt`
- [ ] Conflict record stores: entryId, localVersion (full JSON), remoteVersion (full JSON), resolution (PENDING), createdAt
- [ ] After conflict detection, the incoming entry is NOT auto-applied — it stays in the conflict table
- [ ] The sync response includes a count of conflicts detected
- [ ] Conflict records are deduplicated: if entry E1 already has an unresolved conflict, new conflict replaces it

### Edge Cases
- Entry deleted on one side, modified on other: treat as conflict (both are changes)
- Entry ID collision (UUID v4 collision): astronomically unlikely, not handled for MVP
- Conflict on first sync: impossible (first sync has no lastSyncAt, so all entries are new)

### Dependencies
- SYNC-DELTA-01 (delta sync provides lastSyncAt context)
- SYNC-DB-01 (conflicts table)

---

## 6. SYNC-CONFLICT-02: Conflict Resolution UI (ConflictView)

**ID:** SYNC-CONFLICT-02
**Title:** Conflict Resolution UI — Side-by-side diff and resolution

### User Story
As a Taúl user, when a sync conflict occurs, I want to see both versions side-by-side and choose which to keep, so that I have full control over my data.

### System Requirement
The ConflictView screen displays a list of unresolved conflicts. Tapping a conflict shows local and remote versions side-by-side with a diff view. The user can: (a) keep local, (b) keep remote, or (c) keep both (local wins, remote archived).

### Scenarios

**GIVEN** there are 3 unresolved conflicts
**WHEN** the user opens ConflictView
**THEN** a list of 3 conflict cards is shown, each with entry title, timestamps, and "Resolve" button.

**GIVEN** the user taps a conflict card
**WHEN** ConflictView detail opens
**THEN** a side-by-side diff shows local (left) vs remote (right) with highlighted differences in title, content, tags, and metadata.

**GIVEN** the user taps "Keep Local"
**WHEN** the resolution is applied
**THEN** the local version stays in the entries table, the remote version is discarded, and the conflict record is marked RESOLVED with `resolution = KEEP_LOCAL`.

**GIVEN** the user taps "Keep Remote"
**WHEN** the resolution is applied
**THEN** the remote version replaces the local entry (same ID, updated fields + updatedAt), and the conflict is marked RESOLVED with `resolution = KEEP_REMOTE`.

**GIVEN** the user taps "Keep Both"
**WHEN** the resolution is applied
**THEN** the local version stays in the entries table, the remote version is saved as a new entry with a new UUID (prefix `conflict_` + original ID), and the conflict is marked RESOLVED with `resolution = KEEP_BOTH`.

**GIVEN** the user taps "Resolve All" with a default strategy
**WHEN** all conflicts are resolved at once
**THEN** all conflicts are resolved using the chosen strategy (e.g., "keep local for all").

### Acceptance Criteria
- [ ] ConflictView shows a list of all unresolved conflicts (resolution = PENDING)
- [ ] Side-by-side diff highlights: title, content, tags, metadata differences
- [ ] Three resolution options: Keep Local, Keep Remote, Keep Both
- [ ] "Keep Both" creates a new entry with ID = `conflict_<originalId>_<timestamp>`
- [ ] "Keep Remote" overwrites local entry fields (preserving local ID)
- [ ] Resolving a conflict marks it RESOLVED in the conflicts table
- [ ] Conflict count badge on SyncView shows unresolved count
- [ ] "Resolve All" option with strategy selection (keep local / keep remote)

### Edge Cases
- Conflict entry was deleted locally: show "Deleted locally" badge, only "Keep Remote" is active
- Conflict entry was deleted remotely: show "Deleted remotely" badge, only "Keep Local" is active
- Very large diff: truncate at 5000 chars with "Show more" expand
- User exits without resolving: conflicts remain PENDING, next sync re-detects them

### Dependencies
- SYNC-CONFLICT-01 (conflict detection creates the records)
- SYNC-DB-01 (conflicts table)

---

## 7. SYNC-UI-01: Sync Status UI (SyncView)

**ID:** SYNC-UI-01
**Title:** SyncView — Main sync screen with status, QR code, and conflict badge

### User Story
As a Taúl user, I want a dedicated sync screen where I can start a sync, see connection status, and access conflict resolution.

### System Requirement
The SyncView screen is the entry point for all sync operations. It shows: device ID, sync status (idle/connecting/syncing/complete/error), QR code for pairing, conflict count badge, and a "Start Sync" / "Stop Sync" button.

### Scenarios

**GIVEN** the user is on the SyncView and sync has not started
**WHEN** the screen loads
**THEN** it shows the device's local name/ID, a "Start Sync" button, and conflict count badge (0 if no conflicts).

**GIVEN** the user taps "Start Sync"
**WHEN** the server starts successfully
**THEN** a QR code is displayed with the server URL, a 6-digit code is shown, and status changes to "Waiting for connection...".

**GIVEN** a remote device connects and pairing succeeds
**WHEN** sync begins
**THEN** a progress indicator shows entries being exchanged, status = "Syncing...".

**GIVEN** sync completes
**WHEN** the response is processed
**THEN** status = "Sync complete — N entries synced, M conflicts detected", and the conflict badge updates.

**GIVEN** the user taps "Stop Sync"
**WHEN** the server is running
**THEN** the server shuts down, QR code disappears, status = "Sync stopped".

**GIVEN** the conflict badge shows M > 0
**WHEN** the user taps the badge
**THEN** ConflictView opens.

### Acceptance Criteria
- [ ] SyncView accessible from home_view.dart sync button
- [ ] Device ID displayed (UUID from SharedPreferences, truncated for display)
- [ ] "Start Sync" button starts server, shows QR + code
- [ ] "Stop Sync" button shuts down server
- [ ] Status indicator: idle → connecting → syncing → complete/error
- [ ] QR code + 6-digit code displayed during pairing phase
- [ ] Conflict count badge shown when unresolved conflicts exist
- [ ] Tap badge → navigates to ConflictView
- [ ] Vault LOCKED state shows "Unlock vault to sync" message

### Edge Cases
- Navigation away from SyncView while server running: auto-stop server
- Multiple taps on "Start Sync": idempotent, no duplicate servers
- App backgrounded during sync: sync continues if < 30s, aborts if longer

### Dependencies
- SYNC-PROTOCOL-01 (server)
- SYNC-PAIR-01 (QR code)
- SYNC-CONFLICT-01 (conflict count)

---

## 8. SYNC-SECURITY-01: TLS Certificate and Pairing Security

**ID:** SYNC-SECURITY-01
**Title:** TLS Security — Self-signed certs, pairing code validation, DEK isolation

### User Story
As a Taúl user, I want my sync traffic encrypted and my secrets protected, so that sync is secure even on untrusted networks.

### System Requirement
All sync communication uses TLS with a self-signed certificate. The pairing code serves as the trust anchor (cert fingerprint validated via code). The DEK (Data Encryption Key) is NEVER transmitted — each device decrypts secrets with its own DEK. Encrypted secrets travel as opaque blobs.

### Scenarios

**GIVEN** Device A generates a self-signed certificate
**WHEN** the cert is created
**THEN** it uses RSA 2048-bit, SHA-256, valid for 1 year, with CN = device UUID. The SHA-256 fingerprint is embedded in the pairing code validation.

**GIVEN** Device B connects to Device A
**WHEN** TLS handshake occurs
**THEN** Device B validates the certificate fingerprint against the one derived from the pairing code (6-digit code maps to a subset of the fingerprint for validation).

**GIVEN** Device A sends encrypted secrets (encryptedSecret, cipherNonce, cipherTag)
**WHEN** Device B receives them
**THEN** Device B stores them as-is — they remain encrypted with Device A's DEK. Device B cannot decrypt them unless it has the same DEK (which it doesn't for cross-device scenarios).

**GIVEN** Device A and Device B share the same master password
**WHEN** sync occurs
**THEN** both devices use the same DEK (derived from the same master password via Argon2id), so encrypted secrets from either device can be decrypted by the other.

**GIVEN** Device A and Device B have DIFFERENT master passwords
**WHEN** sync occurs
**THEN** encrypted secrets from the other device cannot be decrypted locally — the app shows "Encrypted by another device" placeholder.

### Acceptance Criteria
- [ ] Self-signed cert: RSA 2048-bit, SHA-256, CN = device UUID, valid 1 year
- [ ] Cert stored in app documents dir as `sync_cert.pem` + `sync_key.pem`
- [ ] TLS enforced — no unencrypted HTTP fallback
- [ ] Pairing code (6 digits) validates cert fingerprint
- [ ] DEK is never transmitted over the wire
- [ ] Encrypted secrets travel as 3 fields: encryptedSecret, cipherNonce, cipherTag
- [ ] Secrets are decrypted locally only, never sent in cleartext
- [ ] If DEK mismatch (different master passwords), encrypted secrets show placeholder

### Edge Cases
- Cert expires: regenerate on next sync attempt
- Cert file corrupted: regenerate, re-pair required
- Man-in-the-middle: pairing code prevents MITM (cert pinned to code)
- Same master password on both devices: full secret decryption works

### Dependencies
- SYNC-PROTOCOL-01/02 (server/client use TLS)

---

## 9. SYNC-DB-01: Database Migration v11 — Conflicts Table

**ID:** SYNC-DB-01
**Title:** Database Migration v11 — Add `conflicts` table and sync metadata

### User Story
As a developer, I need a database schema that supports conflict tracking so that the sync feature can persist and resolve conflicts across sessions.

### System Requirement
Migration v11 adds a `conflicts` table to track sync conflicts. Each conflict record links an entry ID to its local and remote versions, tracks resolution state, and stores timestamps.

### Scenarios

**GIVEN** the database is at schema version 10
**WHEN** the app starts with the new code
**THEN** migration v11 runs: creates `conflicts` table and bumps schema to 11.

**GIVEN** migration v11 has run
**WHEN** a conflict is detected during sync
**THEN** a row is inserted into `conflicts` with entryId, localVersion (JSON), remoteVersion (JSON), resolution = PENDING, createdAt.

**GIVEN** the `conflicts` table exists
**WHEN** the user resolves a conflict
**THEN** the row's `resolution` is updated to KEEP_LOCAL, KEEP_REMOTE, or KEEP_BOTH, and `resolvedAt` is set.

**GIVEN** a new install (no existing DB)
**WHEN** the DB is created
**THEN** `conflicts` table exists from onCreate.

### Schema

```sql
CREATE TABLE conflicts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entry_id TEXT NOT NULL,
  local_version TEXT NOT NULL,      -- JSON blob of local Entry
  remote_version TEXT NOT NULL,     -- JSON blob of remote Entry
  resolution TEXT NOT NULL DEFAULT 'PENDING',  -- PENDING | KEEP_LOCAL | KEEP_REMOTE | KEEP_BOTH
  created_at DATETIME NOT NULL,
  resolved_at DATETIME,
  peer_device_id TEXT NOT NULL      -- UUID of the remote device
);

CREATE INDEX idx_conflicts_entry_id ON conflicts(entry_id);
CREATE INDEX idx_conflicts_resolution ON conflicts(resolution);
```

### Acceptance Criteria
- [ ] Migration v11 creates `conflicts` table with all columns above
- [ ] Migration is forward-only (no down migration needed)
- [ ] Existing DBs are migrated without data loss
- [ ] `conflicts` table is registered in `@DriftDatabase` annotation
- [ ] Drift DAO for conflicts: insert, update resolution, query by resolution, query by entryId
- [ ] `conflicts` table is included in `_createFtsTable` exclusion (no FTS indexing)

### Edge Cases
- Migration fails: show error, do not proceed (existing pattern)
- Schema 11 already exists: skip migration (idempotent)
- Large number of conflicts: query with pagination support

### Dependencies
- None (standalone DB change)

---

## 10. SYNC-DB-02: Device ID Persistence

**ID:** SYNC-DB-02
**Title:** Device ID — Persistent UUID stored in SharedPreferences

### User Story
As a developer, I need a stable device identifier so that sync can track which device modified which entry.

### System Requirement
On first launch, generate a UUID v4 and store it in SharedPreferences as `device_id`. This ID is used in sync payloads as the `deviceId` field and is immutable for the app's lifetime.

### Scenarios

**GIVEN** the app is launched for the first time
**WHEN** SharedPreferences has no `device_id`
**THEN** a UUID v4 is generated and stored as `device_id`.

**GIVEN** `device_id` exists in SharedPreferences
**WHEN** the app starts
**THEN** the existing ID is loaded and used for sync.

**GIVEN** the user clears app data
**WHEN** SharedPreferences is wiped
**THEN** a new UUID is generated on next launch (old device effectively becomes a "new" device).

### Acceptance Criteria
- [ ] Device ID is a UUID v4, stored as string in SharedPreferences key `device_id`
- [ ] Device ID is generated once, never changes (unless app data is cleared)
- [ ] Device ID is included in sync payloads as `deviceId`
- [ ] Device ID is displayed (truncated) on SyncView for user reference

### Edge Cases
- SharedPreferences read failure: generate new UUID, log warning
- UUID format validation: reject malformed values, regenerate

### Dependencies
- None (standalone utility)

---

## 11. SYNC-SECURITY-02: Vault State Transitions

**ID:** SYNC-SECURITY-02
**Title:** VaultState — PAIRING and SYNCING states

### User Story
As a user, I want visual feedback about the vault's sync state so I know what's happening.

### System Requirement
Extend `VaultState` (from SDD design) to include LOCKED, UNLOCKED, PAIRING, SYNCING, and ERROR states. Sync operations transition between these states.

### Scenarios

**GIVEN** the vault is LOCKED
**WHEN** the user taps "Start Sync"
**THEN** state stays LOCKED, error message shown.

**GIVEN** the vault is UNLOCKED
**WHEN** the user taps "Start Sync"
**THEN** state transitions to PAIRING (server running, waiting for connection).

**GIVEN** the state is PAIRING
**WHEN** a remote device connects and pairing code is validated
**THEN** state transitions to SYNCING (entries being exchanged).

**GIVEN** the state is SYNCING
**WHEN** sync completes
**THEN** state transitions back to UNLOCKED.

**GIVEN** the state is SYNCING
**WHEN** an error occurs (timeout, disconnect, etc.)
**THEN** state transitions to ERROR with error message, then returns to UNLOCKED after 3 seconds.

### Acceptance Criteria
- [ ] VaultState enum: LOCKED, UNLOCKED, PAIRING, SYNCING, ERROR
- [ ] Sync button disabled when LOCKED
- [ ] Sync button shows "Stop" when PAIRING or SYNCING
- [ ] Error state auto-dismisses after 3 seconds
- [ ] State transitions are visible in the UI (status bar, button text, progress indicator)

### Edge Cases
- Rapid state transitions: debounce, only show latest state
- State persisted across app restart: reset to UNLOCKED on restart (sync is session-based)

### Dependencies
- SYNC-PROTOCOL-01 (server triggers PAIRING state)
- SYNC-PAIR-01 (pairing validates code, transitions to SYNCING)

---

## 12. SYNC-UI-02: Sync Route Integration

**ID:** SYNC-UI-02
**Title:** Route Integration — SyncView added to go_router

### User Story
As a user, I want to access the sync screen from the home screen's sync button.

### System Requirement
Add a `/sync` route to the go_router configuration. The sync button on `home_view.dart` navigates to SyncView instead of showing a "coming in Phase 3" SnackBar.

### Scenarios

**GIVEN** the user taps the sync button on the home screen
**WHEN** navigation occurs
**THEN** SyncView is displayed at `/sync`.

**GIVEN** the user is on SyncView
**WHEN** they press back
**THEN** they return to the home screen.

### Acceptance Criteria
- [ ] `/sync` route added to `app.dart` ShellRoute or direct route
- [ ] SyncView is the destination
- [ ] Sync button in `home_view.dart:511` navigates to `/sync`
- [ ] "Sync coming in Phase 3" SnackBar is removed
- [ ] SyncView respects the existing theme and layout conventions

### Edge Cases
- Deep link to `/sync` while vault locked: redirect to home with message
- SyncView opened while sync is running (e.g., after app restart): show idle state (sync is session-based)

### Dependencies
- SYNC-UI-01 (SyncView screen)

---

## Capability Map

| Capability | Specs | Status |
|------------|-------|--------|
| sync-protocol | SYNC-PROTOCOL-01, SYNC-PROTOCOL-02 | New |
| sync-pairing | SYNC-PAIR-01 | New |
| sync-delta | SYNC-DELTA-01 | New |
| conflict-detection | SYNC-CONFLICT-01 | New |
| conflict-resolution | SYNC-CONFLICT-02 | New |
| sync-ui | SYNC-UI-01, SYNC-UI-02 | New |
| sync-security | SYNC-SECURITY-01, SYNC-SECURITY-02 | New |
| sync-db | SYNC-DB-01, SYNC-DB-02 | New |

## Implementation Order

1. **SYNC-DB-01** + **SYNC-DB-02** — Schema foundation (no dependencies)
2. **SYNC-SECURITY-01** + **SYNC-SECURITY-02** — Security model + vault states
3. **SYNC-PROTOCOL-01** — HTTPS server
4. **SYNC-PAIR-01** — QR pairing
5. **SYNC-DELTA-01** — Delta sync logic
6. **SYNC-CONFLICT-01** — Conflict detection
7. **SYNC-PROTOCOL-02** — HTTPS client
8. **SYNC-UI-01** + **SYNC-UI-02** — UI integration
9. **SYNC-CONFLICT-02** — Conflict resolution UI
