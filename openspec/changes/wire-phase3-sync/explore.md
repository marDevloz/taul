# Exploration: Wire Phase 3 Sync

## Change
`wire-phase3-sync`

## Current State

### What's Working
The entire infrastructure layer is built and tested:
- `lib/infrastructure/sync/certificate_manager.dart` — Self-signed X.509 (RSA 2048/SHA-256), stores cert+key in app docs dir, renews at 365 days
- `lib/infrastructure/sync/sync_server.dart` — Shelf HTTPS server, random port (49152–65535), POST /sync endpoint, validates X-Pairing-Code header, 401/429 responses, 5min inactivity auto-shutdown, port conflict retry (5 attempts)
- `lib/infrastructure/sync/sync_client.dart` — HTTPS client, TLS fingerprint validation, 10s connect/30s read timeout, chunked send for 100+ entries, retry on rate limit (3 attempts), handles 200/401/409/429/5xx
- `lib/infrastructure/sync/sync_wire_format.dart` — SyncRequest/SyncResponse/SyncErrorResponse freezed models with JSON serialization
- `lib/infrastructure/sync/pairing_service.dart` — 6-digit code generator, 3-attempt lockout, IP detection
- `lib/infrastructure/sync/sync_repository_impl.dart` — ISyncRepository: getModifiedEntries, upsertEntries, conflict management, lastSyncAt via SharedPreferences

Domain layer:
- `lib/domain/entities/conflict.dart` + `conflict_resolution.dart` — Conflict entity with 4 resolution types
- `lib/domain/entities/sync_state.dart` — State machine: idle → pairing → syncing → complete/error
- `lib/domain/repositories/i_sync_repository.dart` — Abstract interface
- `lib/domain/services/conflict_resolver.dart` — detectConflicts (by updatedAt vs lastSyncAt) + resolveConflict

UI layer:
- `lib/ui/screens/sync_view.dart` — Sync screen with device ID display, status indicator, start/stop button, QR placeholder, conflict count badge
- `lib/ui/screens/conflict_view.dart` — Conflict list + detail with side-by-side diff, 3 resolution options (keepLocal/keepRemote/keepBoth)
- `lib/ui/providers/sync_providers.dart` — syncStateProvider, conflictCountProvider, startSyncProvider, stopSyncProvider, resolveConflictProvider
- `lib/ui/providers/device_id_provider.dart` — UUID device ID from SharedPreferences

Routing:
- `/sync` route in GoRouter (app.dart)
- `/sync/conflicts` as sub-route
- Sync button in home_view.dart navigates to /sync

Tests (6 files in test/infrastructure/sync/):
- sync_wire_format_test.dart, sync_service_test.dart, sync_server_test.dart, sync_client_test.dart, pairing_service_test.dart, certificate_manager_test.dart

Database:
- Migration v11: conflicts table exists with indexes
- ConflictDao fully implemented (insert, updateResolution, getByResolution, getByEntryId, getPendingCount)

### What's Missing / Broken

The core problem: **infrastructure exists but is never wired together**. There is no orchestration that connects server → service → repository → conflict resolver → UI into a working sync flow.

## Gap Analysis

| Spec ID | Requirement | Status | What's Needed |
|---------|------------|--------|---------------|
| SYNC-PROTOCOL-01 | Server processes POST /sync, validates pairing code, returns entries modified since lastSyncAt | ⚠️ Server exists, validates pairing code, but `onRequest` callback is never connected to real logic | Implement `onRequest` handler: 1. receive remote entries, 2. detect conflicts with local entries via ConflictResolver, 3. respond with local modified entries + conflict count |
| SYNC-PROTOCOL-02 | Client sends local entries, receives remote entries, upserts them locally | ⚠️ Client exists with all error handling, but `performSync` never called in a real flow | Connect SyncService.performSync → SyncClient.sync → process response → SyncRepositoryImpl.upsertEntries |
| SYNC-PAIR-01 | QR code with real IP:port + 6-digit pairing code | ❌ QR hardcoded `'https://sync.taul.local'`. No scanner, no manual URL entry | Generate QR from PairingService.getLocalIpAddress() + server.port + pairing code |
| SYNC-DELTA-01 | Delta sync: only entries modified since lastSyncAt | ❌ SyncRepositoryImpl.getModifiedEntries exists, but never called in a real sync flow | Wire getModifiedEntries into the sync request creation flow |
| SYNC-CONFLICT-01 | Conflict detection on receive | ❌ ConflictResolver.detectConflicts exists, but never called during sync | Call detectConflicts when remote entries arrive, store conflicts in DB |
| SYNC-CONFLICT-02 | Conflict resolution UI | ✅ ConflictView shows conflicts, lets user pick resolution | Works — but no "Resolve All" batch option |
| SYNC-UI-01 | SyncView with real QR, code, progress | ❌ QR hardcoded, no 6-digit code display, no progress indicator | Wire real pairing data into SyncView, add progress feedback |
| SYNC-SECURITY-01 | TLS + DEK isolation for secrets | ⚠️ TLS works. DEK isolation never implemented | Crypto policy needed: secrets travel as opaque blobs, same-master-password = decryptable, different = placeholder |
| SYNC-SECURITY-02 | Vault states: PAIRING, SYNCING | ⚠️ SyncState enum exists, state transitions work in SyncService, but UI states not fully wired | SyncView uses SyncState but only basic states shown |
| SYNC-DB-01 | Conflicts table | ✅ Complete | — |
| SYNC-DB-02 | Device ID persistence | ✅ Complete | — |
| SYNC-UI-02 | Route integration | ✅ Complete | — |

## Root Causes

1. **The 2026-06-09 change was archived incomplete**: all task checkboxes were marked done, but the critical wiring (instantiating SyncService, implementing onRequest, connecting the flow) was never actually coded. Likely the "Polish + integration tests" PR was never truly completed.

2. **No domain use cases**: Sync logic lives directly in infrastructure (`sync_service.dart`, `sync_repository_impl.dart`) with no domain service or use case layer. This means business logic (conflict detection policy, delta sync rules, crypto policy) is mixed with IO.

3. **syncServiceProvider is a placeholder**: `lib/ui/providers/sync_providers.dart:10` returns `null` — the single most critical blocker.

4. **No crypto cross-device policy**: The spec says "DEK never transmitted" but there's no code handling what happens when two devices have different master passwords. Protected entries would sync but be undecryptable on the other device.

## Recommendations

### Approach 1: Minimal Wiring (recommended for this change)
Connect existing infrastructure without refactoring the architecture:
1. Implement `onRequest` handler that processes incoming entries, detects conflicts, returns modified local entries
2. Create the full sync flow in SyncService or a new `SyncCoordinator`
3. Wire `syncServiceProvider` with real dependencies
4. Generate real QR data + pairing code in SyncView
5. Add crypto policy for protected entries (opaque blob transfer, same-DEK detection)
6. Add integration tests

**Pros**: Fastest path to working sync, reuses all existing code  
**Cons**: Sync logic stays in infrastructure layer, no domain use cases

### Approach 2: Full Rework with Domain Layer
Move sync orchestration to domain layer with proper use cases:
1. Create `SyncUseCase` in `lib/domain/usecases/`
2. Move conflict detection policy into domain
3. Create `ISyncProtocol` interface (abstract server/client)
4. Then wire everything

**Pros**: Clean architecture compliance, testable in isolation  
**Cons**: Much larger change, would rewrite working infrastructure  

### Recommendation
**Approach 1** for this change. The existing code is solid — it just needs to be connected. The domain layer can be refactored in a follow-up if needed.

## Key Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `lib/infrastructure/sync/sync_coordinator.dart` | Create | Orchestrates the full sync flow: accept remote entries, detect conflicts, return local delta |
| `lib/ui/providers/sync_providers.dart` | Modify | Instantiate SyncService with real dependencies instead of null |
| `lib/ui/screens/sync_view.dart` | Modify | Show real QR with IP:port + pairing code |
| `lib/infrastructure/sync/sync_service.dart` | Modify | Add sync flow methods (or delegate to coordinator) |
| `lib/infrastructure/sync/sync_repository_impl.dart` | Modify (minor) | Add tagsColors to sync payload |
| Test files | Create | Integration tests for full sync flow |
