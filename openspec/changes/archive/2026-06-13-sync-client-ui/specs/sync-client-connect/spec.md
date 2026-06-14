# Sync Client Connect — Specification

## Purpose

Client-side sync initiation and response processing. Device B enters a remote address + pairing code, performs a sync, upserts received entries, stores conflicts, and updates `lastSyncAt`.

---

## Requirements

### Requirement: SYNC-CLIENT-UI-01 — Connect Bottom Sheet

The system SHALL display a bottom sheet (`SyncConnectSheet`) with two text fields (remote URL, pairing code) and a "Conectar" button.

#### Scenario: Open connect sheet

- GIVEN the user is on SyncView in idle or complete state
- WHEN the user taps "Conectar a dispositivo"
- THEN a bottom sheet opens with URL field (prefilled with `https://`), pairing code field (6-digit), and Connect button

#### Scenario: Submit valid credentials

- GIVEN the connect sheet is open with a valid URL and 6-digit code
- WHEN the user taps Connect
- THEN the sheet closes and SyncState transitions to `connecting`

#### Scenario: Submit empty or invalid fields

- GIVEN the URL field is empty or the pairing code is not 6 digits
- WHEN the user taps Connect
- THEN the button is disabled and no action is taken

---

### Requirement: SYNC-CLIENT-UI-02 — Client Sync State

The system SHALL add a `connecting` state to the `SyncState` enum. The state machine SHALL be: `idle → connecting → syncing → complete | error`.

#### Scenario: State transitions on successful sync

- GIVEN the client is in `connecting` state
- WHEN the sync completes successfully
- THEN the state transitions to `complete` with result data available

#### Scenario: State transitions on failure

- GIVEN the client is in `connecting` or `syncing` state
- WHEN the sync fails with any error
- THEN the state transitions to `error` with the error message available

---

### Requirement: SYNC-CLIENT-UI-03 — Connect and Sync Provider

The system SHALL provide a `connectAndSyncProvider` that orchestrates: (1) compute local delta via `ISyncRepository.getModifiedEntries`, (2) build `SyncRequest` with deviceId and entries, (3) call `SyncService.performSync(url, code, request)`, (4) process the response, (5) return result summary.

#### Scenario: Successful bidirectional sync

- GIVEN Device B has 3 entries modified since lastSyncAt
- WHEN connectAndSyncProvider executes with valid URL and code
- THEN SyncService.performSync is called with correct request
- AND response entries are upserted via SyncRepositoryImpl
- AND response conflicts are stored via ConflictDao
- AND lastSyncAt is updated with `response.serverLastSyncAt`
- AND a result summary is returned with `entriesSynced` and `conflictsCount`

#### Scenario: First sync — no lastSyncAt

- GIVEN Device B has never synced (lastSyncAt is null)
- WHEN connectAndSyncProvider executes
- THEN all local entries are sent as the delta
- AND the response is processed the same as any sync

---

### Requirement: SYNC-CLIENT-UI-04 — Sync Response Processing

The system SHALL implement `SyncCoordinator.processSyncResponse(SyncResponse)` that: (1) upserts `response.entries` via `ISyncRepository.upsertEntries`, (2) does NOT re-detect conflicts (server already did), (3) updates `lastSyncAt` with `response.serverLastSyncAt`.

#### Scenario: Response with no conflicts

- GIVEN a SyncResponse with 5 entries and conflictsCount = 0
- WHEN processSyncResponse executes
- THEN all 5 entries are upserted
- AND lastSyncAt is set to `response.serverLastSyncAt`
- AND no conflict records are created

#### Scenario: Response with conflicts

- GIVEN a SyncResponse with 3 entries and conflictsCount = 2
- WHEN processSyncResponse executes
- THEN entries without conflicts are upserted
- AND the response includes the conflicting entry IDs (server stored the Conflict records)
- AND lastSyncAt is still updated
- AND the UI displays "2 conflictos — resolútalos"

#### Scenario: Response with undecryptable protected entry

- GIVEN a SyncResponse includes a protected entry whose DEK doesn't match
- WHEN processSyncResponse upserts it
- THEN the entry is stored as-is (opaque blob)
- AND the UI shows "Encriptado por otro dispositivo" placeholder on open

---

### Requirement: SYNC-CLIENT-UI-05 — Sync Result Summary

The system SHALL display a result summary in SyncView after a client sync completes: entries synced count, conflict count, and last sync timestamp.

#### Scenario: Sync complete with conflicts

- GIVEN a client sync completed with 10 entries synced and 2 conflicts
- WHEN SyncView renders the complete state
- THEN it shows "10 entradas sincronizadas, 2 conflictos"
- AND a "Resolver conflictos" button navigates to `/sync/conflicts`

#### Scenario: Sync complete with no conflicts

- GIVEN a client sync completed with 7 entries synced and 0 conflicts
- WHEN SyncView renders the complete state
- THEN it shows "7 entradas sincronizadas, sin conflictos"
- AND no conflict resolution button is shown

---

### Requirement: SYNC-CLIENT-UI-06 — Error Handling

The system SHALL handle these error scenarios and display the error message in SyncView error state:

#### Scenario: Wrong pairing code (401)

- GIVEN the user enters an incorrect pairing code
- WHEN SyncClient receives a 401 response
- THEN the error "Código de emparejamiento incorrecto" is shown

#### Scenario: Server unreachable

- GIVEN the remote server is not running at the given URL
- WHEN the connection attempt fails
- THEN the error "Servidor no encontrado — verificar URL" is shown

#### Scenario: TLS fingerprint mismatch

- GIVEN the remote server presents an unknown TLS certificate
- WHEN the TLS handshake fails
- THEN the error "Certificado desconocido — reconectar" is shown

#### Scenario: Timeout

- GIVEN the server does not respond within the timeout
- WHEN the request times out
- THEN the error "Conexión agotada — intentar de nuevo" is shown

---

## Out of Scope

- QR scanning (no `mobile_scanner` dependency)
- Auto-discovery (mDNS, LAN broadcast)
- Background/periodic sync
- Conflict resolution UI changes (reuse existing `conflict_view.dart`)
