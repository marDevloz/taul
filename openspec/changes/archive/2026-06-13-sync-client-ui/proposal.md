# Proposal: Sync Client UI

## Intent

The sync feature works for Device A (host) — shows QR, starts HTTPS server, waits for Device B. But there is NO client-side flow: Device B has no way to enter a remote address + pairing code, initiate `SyncClient.sync()`, or process the `SyncResponse`. The bidirectional sync protocol is built but only half wired.

## Scope

### In Scope
- `SyncConnectSheet` — bottom sheet for entering remote URL + pairing code (desktop-first, text fields)
- Client-side response processing in `SyncCoordinator.processSyncResponse()` — upsert entries, store conflicts, update `lastSyncAt`
- `connectAndSyncProvider` — orchestrates: get local delta → build `SyncRequest` → call `SyncService.performSync()` → process response → show summary
- Sync result summary in `SyncView` (entries synced, conflicts, last sync time)
- `lastSyncAt` persistence after successful sync (already in `SyncRepositoryImpl`, just needs wiring)

### Out of Scope
- QR scanning (no `mobile_scanner` dependency — deferred)
- Auto-discovery (mDNS, LAN broadcast — deferred)
- Background/periodic sync (manual trigger only)
- Conflict resolution UI changes (reuse existing `conflict_view.dart`)

## Capabilities

### New Capabilities
- `sync-client-connect`: Client-side sync initiation UI and response processing — enter remote address, perform sync, upsert response entries, store conflicts, update lastSyncAt

### Modified Capabilities
None. Existing capabilities (`sync-orchestration`, `sync-pairing`, `sync-security`) are unchanged.

## Approach

**Recommended: Approach 1 — Reuse SyncCoordinator, minimal new code.**

The `SyncCoordinator` is symmetric: `handleSyncRequest` already does conflict detection, entry upsert, and timestamp recording. Add `processSyncResponse(SyncResponse)` — same logic, different input (response entries instead of request entries). No new class needed.

### Architecture (layer impact: ui + infrastructure)

```
lib/ui/screens/sync_connect_sheet.dart          (NEW — ~100 lines)
lib/ui/providers/sync_client_providers.dart     (NEW — ~80 lines)
lib/infrastructure/sync/sync_coordinator.dart   (MODIFY — +30 lines, add processSyncResponse)
lib/ui/screens/sync_view.dart                   (MODIFY — +60 lines, add connect button + results)
lib/ui/providers/sync_providers.dart            (MODIFY — +20 lines, expose connect providers)
lib/domain/entities/sync_state.dart             (MODIFY — +1 state: connecting)
test/infrastructure/sync/sync_coordinator_test.dart (MODIFY — +50 lines)
test/ui/screens/sync_view_test.dart             (MODIFY — +40 lines)
```

**Estimated total: ~130 lines new + ~200 lines modified = ~330 lines** (within 400-line budget)

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/infrastructure/sync/sync_coordinator.dart` | Modified | Add `processSyncResponse()` method for client-side response processing |
| `lib/ui/screens/sync_connect_sheet.dart` | New | Bottom sheet: URL + pairing code input fields, Connect button |
| `lib/ui/providers/sync_client_providers.dart` | New | `connectAndSyncProvider` — full client-side orchestration |
| `lib/ui/screens/sync_view.dart` | Modified | Add "Conectar a dispositivo" section in idle/complete state, show sync results |
| `lib/ui/providers/sync_providers.dart` | Modified | Expose `connectAndSyncProvider` from client providers |
| `lib/domain/entities/sync_state.dart` | Modified | Add `connecting` state to enum |
| `test/infrastructure/sync/sync_coordinator_test.dart` | Modified | Test `processSyncResponse` with conflicts and clean upsert |
| `test/ui/screens/sync_view_test.dart` | Modified | Test connect UI rendering, error states, results display |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| TLS fingerprint — client needs expected fingerprint before connecting | Medium | Accept fingerprint on first connect, store in SharedPreferences, warn on mismatch |
| 400-line budget — borderline at ~330 estimated | Low | Chain into 2 PRs if needed: (1) coordinator + provider, (2) UI + tests |
| SyncState `connecting` breaks existing state switch exhaustiveness | Low | Add as new enum value, update all switch expressions |
| Protected entries undecryptable after sync (DEK mismatch) | High (by design) | Already documented — show "encrypted by another device" placeholder |

## Rollback Plan

All changes are additive — new files + method additions to existing classes. Revert by:
1. Delete `sync_connect_sheet.dart` and `sync_client_providers.dart`
2. Revert modifications to `sync_coordinator.dart`, `sync_view.dart`, `sync_providers.dart`, `sync_state.dart`
3. Delete added test code

No database migration involved. No schema changes.

## Dependencies

- Existing: `SyncClient`, `SyncService`, `SyncCoordinator`, `SyncRepositoryImpl` (all wired)
- Existing: `ConflictDao`, `EntryDao`, `ConflictResolver` (tested)
- No new external dependencies

## Success Criteria

- [ ] Device B can enter URL + pairing code and trigger a sync
- [ ] `SyncService.performSync()` is called with correct params and response is processed
- [ ] Response entries are upserted locally via `SyncRepositoryImpl.upsertEntries`
- [ ] Conflicts are stored via `ConflictDao.insert` and user is prompted to resolve
- [ ] `lastSyncAt` is updated with `response.serverLastSyncAt` after successful sync
- [ ] SyncView shows result summary: "N entradas sincronizadas, M conflictos"
- [ ] Error states handled: wrong pairing code (401), server unreachable, TLS mismatch
- [ ] Unit tests pass for `processSyncResponse` and connect flow
