# Exploration: Sync Client UI

## Change
`sync-client-ui`

## Current State

### What wire-phase3-sync Built (Server-Side ✅)
The entire server-side sync infrastructure is wired and tested:

| File | Status | Purpose |
|------|--------|---------|
| `lib/infrastructure/sync/sync_coordinator.dart` | ✅ Wired | Server-side: receives remote entries, detects conflicts, upserts non-conflicting, returns delta |
| `lib/infrastructure/sync/sync_server.dart` | ✅ Wired | Shelf HTTPS server, POST /sync, X-Pairing-Code validation, auto-shutdown |
| `lib/infrastructure/sync/sync_client.dart` | ✅ Wired | HTTPS client, TLS fingerprint, chunking, retry, 200/401/409/429/5xx |
| `lib/infrastructure/sync/sync_service.dart` | ✅ Wired | State machine, `performSync()` method exists |
| `lib/infrastructure/sync/sync_repository_impl.dart` | ✅ Wired | getModifiedEntries, upsertEntries, conflict mgmt, lastSyncAt |
| `lib/infrastructure/sync/certificate_manager.dart` | ✅ Wired | RSA 2048/SHA-256 self-signed cert |
| `lib/infrastructure/sync/pairing_service.dart` | ✅ Wired | 6-digit code, 3-attempt lockout, IP detection |
| `lib/infrastructure/sync/sync_wire_format.dart` | ✅ Wired | SyncRequest/SyncResponse freezed models |
| `lib/ui/providers/sync_providers.dart` | ✅ Wired | SyncService with real deps, start/stop sync, QR data |
| `lib/ui/screens/sync_view.dart` | ✅ Wired | Server-side UI: dynamic QR, pairing code, status, start/stop |
| `lib/domain/entities/sync_state.dart` | ✅ Done | idle → pairing → syncing → complete/error |
| `lib/domain/services/conflict_resolver.dart` | ✅ Done | detectConflicts + resolveConflict |
| `lib/domain/repositories/i_sync_repository.dart` | ✅ Done | Abstract interface |
| `lib/ui/screens/conflict_view.dart` | ✅ Done | Conflict resolution UI with diff view |
| `test/infrastructure/sync/sync_coordinator_test.dart` | ✅ Done | Unit tests |
| `test/infrastructure/sync/sync_integration_test.dart` | ✅ Done | Mock-based bidirectional test |

### The Critical Gap: Client-Side Connect + Response Processing

**There is NO code for the client-side of a sync session.** Here's what's missing:

1. **No QR scanner / manual URL entry UI**: The QR is only generated and displayed (server role). The other device has no way to input the URL + pairing code. No `mobile_scanner` dependency exists.

2. **`SyncService.performSync()` is never called**: The method exists at `sync_service.dart:52` but no provider or UI ever invokes it. It returns a `SyncResponse` but nothing processes the response.

3. **No response processing**: After `performSync` returns a `SyncResponse`, the client must:
   - Upsert the returned `response.entries` (remote delta) into the local DB
   - Record conflicts from `response.conflictsCount`
   - Update `lastSyncAt` with `response.serverLastSyncAt`
   - Show the user a summary

4. **The provider chain supports server start/stop but not client connect**: `startSyncProvider` starts a server; there's no `connectToDeviceProvider` or equivalent.

### Existing Test Coverage

| Test file | Covers | Status |
|-----------|--------|--------|
| `test/infrastructure/sync/sync_coordinator_test.dart` | Server-side coordinator | ✅ |
| `test/infrastructure/sync/sync_integration_test.dart` | Mock-based bidirectional | ✅ |
| `test/integration/sync_integration_test.dart` | Real E2E | ❌ Stub (creates entries, no actual server/client) |
| `test/ui/screens/sync_view_test.dart` | UI rendering | ✅ But no client-connect tests |

## Navigation & Patterns

- GoRouter with ShellRoute, `/sync` and `/sync/conflicts` routes already exist in `app.dart`
- SyncView accessed from HomeView's sync button (`context.push('/sync')`)
- Other screens use `Navigator.push(MaterialPageRoute(...))` for detail/sheet screens
- Bottom sheets are used for transient input (CreateEntrySheet, QuickAddSheet)
- Pattern: `ConsumerStatefulWidget` for interactive screens, `ConsumerWidget` for read-only

## What Files Need to Be Created/Modified

### New Files

| File | Purpose | Est. Size |
|------|---------|-----------|
| `lib/ui/screens/sync_connect_sheet.dart` | Bottom sheet for entering remote URL + pairing code. Desktop: text fields. Mobile: QR scanner (if `mobile_scanner` added). | ~120 lines |
| `lib/ui/providers/sync_client_providers.dart` | Providers for client-side sync orchestration: connect, sync, process response, show summary | ~150 lines |

### Modified Files

| File | Change | Est. Impact |
|------|--------|-------------|
| `lib/infrastructure/sync/sync_service.dart` | Add `performSyncAndProcess()` that calls `performSync`, then processes the response (upsert entries, update lastSyncAt). Or add a separate response-processing method. | ~30 lines |
| `lib/ui/screens/sync_view.dart` | Add "Connect to device" section when in idle/complete state. Show sync results summary. Different UX for server role vs client role. | ~80 lines |
| `lib/ui/providers/sync_providers.dart` | Add `connectAndSyncProvider` or extend `startSyncProvider` to handle client role. | ~50 lines |
| `pubspec.yaml` | **Maybe** add `mobile_scanner` if QR scanning on mobile is in scope. | 1 line |
| `test/ui/screens/sync_view_test.dart` | Add tests for connect UI, sync results display. | ~100 lines |

## Design Decisions from wire-phase3-sync That Affect This Change

1. **Bidirectional sync in a single HTTP request**: The sync is NOT two separate requests. Device B sends its delta, Device A's SyncCoordinator processes it, and returns A's delta in the same response. The client side only needs to process that response.

2. **SyncCoordinator is symmetric**: The server-side SyncCoordinator already has all the logic needed for processing incoming entries. The client side needs the SAME logic to process the response. We can either:
   - Reuse SyncCoordinator on the client side (it takes `ISyncRepository` and `ConflictDao`)
   - Create a separate response processor

3. **Pairing code + TLS fingerprint**: The 6-digit code is displayed on Device A. Device B enters it manually (no QR-scanning of the code itself, just the URL). The pairing code is sent as `X-Pairing-Code` header.

4. **Delta sync using lastSyncAt**: The client must compute its delta before sending and must update lastSyncAt after receiving.

5. **Manual trigger only**: No background/periodic sync. User manually initiates a sync session.

6. **DEK isolation**: Protected entries are opaque blobs. The UI must show placeholder if decryption fails post-sync.

## User Flow for Client Side

```
Device B (Client)                                        Device A (Server)
─────────────────                                        ──────────────────
1. User taps "Conectar a dispositivo"
2. Enter URL + pairing code
   (or scan QR on mobile)
3. Compute local delta entries
   (getModifiedEntries(lastSyncAt))
4. POST /sync {deviceId, lastSyncAt, entries}
   ──────────────────────────────────────────►    5. SyncCoordinator processes
                                                   6. Returns SyncResponse
   ◄──────────────────────────────────────────       {entries, conflictsCount}
7. Parse SyncResponse
8. Upsert response.entries locally
9. Store conflicts from response
10. Update lastSyncAt
11. Show summary: "N entradas sincronizadas, M conflictos"
12. Navigate to conflicts if M > 0
```

## Approaches

### Approach 1: Minimal — Bottom Sheet + Process Response (Recommended)

Add a "Conectar y sincronizar" button in SyncView that opens a bottom sheet. User fills URL + pairing code. On submit, the client:
- Gets local delta via ISyncRepository.getModifiedEntries
- Sends SyncRequest via SyncClient.sync
- Processes SyncResponse by reusing SyncCoordinator (it's symmetric)
- Shows result in SyncView

**Pros**:
- Minimal new code (~250 lines total)
- Reuses SyncCoordinator logic (symmetric)
- Fits existing UI patterns
- Desktop-friendly (manual entry)
- No new dependencies (no QR scanner needed for desktop-only)

**Cons**:
- SyncCoordinator reused for response processing (works but not its intended API — it expects to be called FROM SyncServer)
- No QR scanning on mobile (can be added later)
- SyncView becomes dual-purpose (server + client)

**Effort**: Medium (~250 lines new + ~150 lines modified)

### Approach 2: Separate Sync Client Screen with Full Orchestration

Create a dedicated `SyncClientScreen`/`SyncConnectScreen` that handles the full client-side flow. Keep SyncView server-only. Add a dedicated `SyncResponseProcessor` class.

**Pros**:
- Clean separation of concerns
- SyncView stays server-focused
- Dedicated response processor is more testable
- Better UX differentiation between "host" and "join"

**Cons**:
- More code (~400 lines total)
- More screens to navigate
- Risk of duplicating SyncCoordinator logic
- Need to decide navigation structure (new route? nested?)

**Effort**: High (~400 lines new + ~100 lines modified)

### Approach 3: Add QR Scanner + Full Mobile UX

Full scope: add `mobile_scanner` package, QR scanning on mobile, manual entry on desktop, plus all the response processing.

**Pros**:
- Full mobile support
- Best UX for users
- Covers SYNC-PAIR-01 spec requirement

**Cons**:
- Large change (~500+ lines)
- New dependency to manage
- Desktop doesn't need scanner (manual entry sufficient)
- Likely exceeds 400-line budget

**Effort**: High (~500+ lines)

## Recommendation

**Approach 1** — Minimal, desktop-focused. This aligns with the existing pattern (the app is primarily a desktop Flutter app). Key points:

1. Add a "Conectar" bottom sheet to SyncView for entering URL + pairing code
2. Add a `SyncResponseProcessor` (or reuse SyncCoordinator) that takes a SyncResponse and processes it locally
3. Add providers for the client-side sync flow
4. Show sync results in SyncView (entries synced, conflicts)
5. QR scanning can be added later as a mobile follow-up

The SyncCoordinator is already symmetric: it takes entries, loads local delta, detects conflicts, upserts, and returns a response. We can reuse it for processing the response by treating the response entries as "remote" and the local state as "local", but this needs careful analysis. Alternatively, a small `SyncResponseProcessor` class that just upserts entries and updates lastSyncAt is simpler and avoids coupling.

## Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Reusing SyncCoordinator for response processing creates confusion | Medium | Medium | Create a simple `SyncResponseProcessor` instead of reusing SyncCoordinator |
| First sync sends all entries — large payload | Low | Medium | Chunked send already implemented in SyncClient (100 entries/chunk) |
| Clock skew causes incorrect delta computation | Medium | Medium | Already mitigated: server timestamp in response is authoritative |
| UI state machine needs client states | Low | Low | Add states to SyncState enum if needed (connecting, scanning) |
| Protected entries undecryptable after sync | High | Low | Already documented: show placeholder when DEK mismatch |
| No test for client-side flow | High | Medium | Must add integration test with real SyncClient → SyncServer → SyncCoordinator |
| 400-line budget risk | Medium | Medium | Approach 1 estimated at ~400 total — borderline. If exceeded, chain into 2 PRs |

## Ready for Proposal

**Yes**. The gap is clear and well-defined: client-side connect UI + response processing. Approach 1 is recommended as it's minimal, desktop-focused, and reuses existing infrastructure. The proposal should clearly scope whether QR scanning is deferred.

## Key Files to Create/Modify

| File | Action | Est. Lines |
|------|--------|-----------|
| `lib/ui/screens/sync_connect_sheet.dart` | **Create** — Bottom sheet for enter URL + pairing code | 120 |
| `lib/ui/providers/sync_client_providers.dart` | **Create** — Client-side sync orchestration + response processing | 150 |
| `lib/infrastructure/sync/sync_service.dart` | **Modify** — Add response processing method | 30 |
| `lib/ui/screens/sync_view.dart` | **Modify** — Add client-connect section + sync results | 80 |
| `lib/ui/providers/sync_providers.dart` | **Modify** — Add client-connect providers | 50 |
| `test/infrastructure/sync/sync_client_test.dart` | **Modify** — Add client-side sync flow tests | 80 |
| `test/ui/screens/sync_view_test.dart` | **Modify** — Add client UI tests | 60 |
