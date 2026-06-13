# Delta Spec: Wire Phase 3 Sync

**Parent Spec:** phase3-sync.md (v1.0)
**Change:** wire-phase3-sync
**Version:** 1.0
**Status:** Draft

---

## 1. SYNC-ORCHESTRATION-01: SyncCoordinator

**ID:** SYNC-ORCHESTRATION-01
**Title:** SyncCoordinator — Orchestrate the full sync exchange

### User Story
As a Taúl user, when two devices sync, I want entries to be exchanged bidirectionally, conflicts detected, and nothing lost.

### System Requirement
A SyncCoordinator class implements the `SyncServer.onRequest` callback. On receiving a POST /sync request, it: (1) loads local entries modified since the remote's `lastSyncAt`, (2) detects conflicts where both sides modified the same entry, (3) stores conflicts in the DB, (4) upserts non-conflicting remote entries, (5) returns local delta with conflict count.

### Scenarios

**GIVEN** Device B sends a SyncRequest with `lastSyncAt = 2026-06-10T00:00:00Z` and 3 entries
**WHEN** SyncCoordinator processes the request
**THEN** it loads local entries modified after `2026-06-10T00:00:00Z`, detects conflicts, stores them, upserts non-conflicting entries, and returns a SyncResponse with the local delta and `conflictsCount`.

**GIVEN** both devices modified entry E1 after `lastSyncAt`
**WHEN** SyncCoordinator detects the conflict
**THEN** a Conflict record is created in the DB with both versions, and the entry is NOT upserted. The response includes E1 in the delta (so the client also detects the conflict).

**GIVEN** remote entry E2 was only modified on Device B
**WHEN** SyncCoordinator processes it
**THEN** E2 is upserted locally (no conflict).

### Acceptance Criteria
- [ ] SyncCoordinator loads local delta via SyncRepositoryImpl.getModifiedEntries
- [ ] SyncCoordinator calls ConflictResolver.detectConflicts for each incoming entry
- [ ] Conflicts stored via SyncRepositoryImpl (which delegates to ConflictDao)
- [ ] Non-conflicting entries upserted via SyncRepositoryImpl.upsertEntries
- [ ] Response includes local delta entries + conflictsCount
- [ ] Response timestamp recorded as serverLastSyncAt

---

## 2. SYNC-PROTOCOL-01-DELTA: Wire onRequest

**ID:** SYNC-PROTOCOL-01-DELTA
**Title:** Wire SyncServer.onRequest to SyncCoordinator

### User Story
As a developer, I want SyncServer.onRequest to process real data instead of being a stub.

### System Requirement
Replace the no-op `onRequest` with SyncCoordinator. The server's POST /sync handler now validates pairing code, delegates to SyncCoordinator, and returns the response.

### Acceptance Criteria
- [ ] SyncServer receives SyncCoordinator as its onRequest
- [ ] Pairing code validation still happens (unchanged)
- [ ] Response goes through syncCoordinator → SyncResponse

---

## 3. SYNC-PAIR-01-DELTA: Real QR + Pairing Code

**ID:** SYNC-PAIR-01-DELTA
**Title:** Dynamic QR code with real IP, port, and pairing code

### User Story
As a Taúl user, I want to scan a real QR code containing the server's IP and port, see the 6-digit pairing code, and complete pairing.

### System Requirement
SyncView generates QR from `https://<local-ip>:<port>` using PairingService.getLocalIpAddress() and the server's actual port. The 6-digit pairing code from PairingService.generateCode() is displayed prominently below the QR code.

### Scenarios

**GIVEN** SyncView is in pairing state
**WHEN** the server is running
**THEN** the QR code encodes `https://192.168.1.X:54321` (real IP + port) and the 6-digit code is shown.

**GIVEN** the user stops and restarts sync
**WHEN** the server restarts (possibly on a different port)
**THEN** a new QR code is generated with the updated port.

### Acceptance Criteria
- [ ] QR data uses real local IP from NetworkInterface
- [ ] QR data includes real server port
- [ ] 6-digit pairing code displayed below QR
- [ ] QR regenerates on server restart (new port binding)

---

## 4. SYNC-SECURITY-01-DELTA: Cross-Device Protected Entries

**ID:** SYNC-SECURITY-01-DELTA
**Title:** Protected entry handling during sync

### User Story
As a Taúl user with protected entries (credentials), I want them to sync securely. If both devices share the same master password, I can decrypt them. If not, I see a placeholder.

### System Requirement
Protected entries (requiresAuth=true) are synced as opaque blobs: encryptedSecret, cipherNonce, cipherTag are transmitted as-is. The receiving device stores them. When the user tries to decrypt, if the DEK doesn't match (decryption fails), show "Encrypted by another device — same master password required".

### Scenarios

**GIVEN** Device A and Device B have the same master password
**WHEN** a protected entry syncs between them
**THEN** the entry can be decrypted on both devices (DEK is identical).

**GIVEN** Device A and Device B have different master passwords
**WHEN** a protected entry syncs between them
**THEN** the entry is stored but shows "Encrypted by another device — same master password required" when opened.

### Acceptance Criteria
- [ ] encryptedSecret, cipherNonce, cipherTag are included in sync payload (already in Entry model)
- [ ] No cleartext secret is ever transmitted
- [ ] DEK is never transmitted (enforced at architecture level)
- [ ] UI shows placeholder when decryption fails on the receiving device

---

## 5. SYNC-DELTA-01-DELTA: Include tagsColors in Sync

**ID:** SYNC-DELTA-01-DELTA
**Title:** Include tagsColors field in sync payload

### System Requirement
The Entry.tagsColors map must be included in the sync payload. Currently the Entry model has `tagsColors` but it must be verified that `SyncRepositoryImpl.upsertEntries` preserves it.

### Acceptance Criteria
- [ ] tagsColors is serialized in SyncRequest entries
- [ ] tagsColors is preserved during upsert

---

## Capability Map

| Capability | Spec | Status |
|------------|------|--------|
| sync-orchestration | SYNC-ORCHESTRATION-01 | New |
| sync-protocol | SYNC-PROTOCOL-01-DELTA | Modified |
| sync-pairing | SYNC-PAIR-01-DELTA | Modified |
| sync-security | SYNC-SECURITY-01-DELTA | Modified |
| sync-delta | SYNC-DELTA-01-DELTA | Modified |
