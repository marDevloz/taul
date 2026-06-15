# Tasks: Sync Client UI

## Review Workload Forecast

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: Low

| Field | Value |
|-------|-------|
| Estimated changed lines | ~300 (120 new + 180 modified) |
| 400-line budget risk | Low |
| Chained PRs recommended | Yes (delivery: force-chained) |
| Suggested split | PR #1 → PR #2 → PR #3 |
| Delivery strategy | force-chained |
| Chain strategy | feature-branch-chain |

### Suggested Work Units

| Unit | Goal | Likely PR | Base Boundary | Lines |
|------|------|-----------|---------------|-------|
| 1 | ProcessSyncResult + processSyncResponse + SyncState.connecting + unit tests | PR #1 | `feature/sync-client-ui` | ~70 |
| 2 | ConnectParams + TLS trust helpers + connectAndSyncProvider + wiring + tests | PR #2 | PR #1 branch | ~130 |
| 3 | SyncConnectSheet widget + SyncView connect/results cards + widget tests | PR #3 | PR #2 branch | ~100 |

---

## PR #1: Foundation — Domain + Infrastructure (~70 lines)

- [x] 1.1 RED: Write failing `SyncCoordinator.processSyncResponse()` tests in `test/infrastructure/sync/sync_coordinator_test.dart` — clean upsert, conflict detection with local delta, conflict storage via ConflictDao, `lastSyncAt` update, undecryptable protected entry
- [x] 1.2 GREEN: Add `ProcessSyncResult` freezed class (entriesUpserted, conflictsCount) to `lib/infrastructure/sync/sync_wire_format.dart`
- [x] 1.3 GREEN: Add `SyncState.connecting` to `lib/domain/entities/sync_state.dart` between `idle` and `pairing`; update `isActive`/`canStart`/`showProgress`
- [x] 1.4 GREEN: Add `processSyncResponse(SyncResponse)` method to `lib/infrastructure/sync/sync_coordinator.dart` — get local delta, detect conflicts, store conflicts, upsert non-conflicting entries, update `lastSyncAt`, return `ProcessSyncResult`
- [x] 1.5 REFACTOR: Run `dart analyze` + `flutter test`, fix any issues, verify _StatusCard switch in `sync_view.dart` handles `connecting`

**Files created:** (none)
**Files modified:** `sync_wire_format.dart`, `sync_state.dart`, `sync_coordinator.dart`, `sync_coordinator_test.dart`, `sync_view.dart` (_StatusCard switch case)

---

## PR #2: Provider Layer — Orchestration (~130 lines)

- [x] 2.1 RED: Write failing tests for `ConnectParams` + `connectAndSyncProvider` with mocked `SyncService` + `SyncCoordinator` — verify delta computed, request built, `performSync` called, response processed, result returned, error states (401, unreachable, TLS mismatch, timeout)
- [x] 2.2 GREEN: Create `ConnectParams` class (host, port, fingerprint, pairingCode) + TLS trust-on-first-use helpers (`SharedPreferences` key `tls_trust_{host:port}`, hex-encode fingerprint) in `lib/ui/providers/sync_client_providers.dart`
- [x] 2.3 GREEN: Create `connectAndSyncProvider` (`FutureProvider.family<ProcessSyncResult, ConnectParams>`) — parse URL, check/establish TLS trust, get local delta, build `SyncRequest`, set state to `connecting`, call `SyncService.performSync()`, call `coordinator.processSyncResponse()`, set state to `complete` or `error`
- [x] 2.4 GREEN: Expose `connectAndSyncProvider` in `lib/ui/providers/sync_providers.dart`
- [x] 2.5 REFACTOR: Run `dart analyze` + `flutter test`, fix any issues

**Files created:** `sync_client_providers.dart`
**Files modified:** `sync_providers.dart`
**Tests:** new test file for sync_client_providers

---

## PR #3: UI Layer — Widgets + Integration (~100 lines)

- [x] 3.1 RED: Write widget tests in `test/ui/screens/sync_view_test.dart` — `SyncConnectSheet` renders URL + code fields, validates empty/invalid before submit, disabled button without 6-digit code; `SyncView` shows connect card in idle/complete, results card with entries+conflicts count, error messages per scenario (wrong code, unreachable, TLS mismatch, timeout)
- [x] 3.2 GREEN: Create `lib/ui/screens/sync_connect_sheet.dart` — `ConsumerStatefulWidget` with `showModalBottomSheet`, URL `TextFormField` (prefilled `https://`), 6-digit pairing code field, `FilledButton`("Conectar"), calls `connectAndSyncProvider`, closes sheet on submit
- [x] 3.3 GREEN: Modify `lib/ui/screens/sync_view.dart` — add `_ConnectCard`(`ListTile` with link icon) visible when `syncState.canStart`; add `_SyncResultCard` showing "N entradas sincronizadas, M conflictos" + "Resolver conflictos" button when conflicts exist
- [x] 3.4 REFACTOR: Run `dart analyze` + `flutter test`, verify all spec scenarios from `specs/sync-client-connect/spec.md` pass

**Files created:** `sync_connect_sheet.dart`
**Files modified:** `sync_view.dart`
**Tests:** `sync_view_test.dart`

---

## Task Dependency Graph

```
PR #1 (Foundation)
  ├─ 1.1 RED: processSyncResponse tests (standalone)
  ├─ 1.2 ProcessSyncResult model (no deps)
  ├─ 1.3 SyncState.connecting (no deps)
  ├─ 1.4 processSyncResponse() (depends on 1.2, same class as handleSyncRequest)
  └─ 1.5 REFACTOR (depends on 1.1-1.4 passing)

PR #2 (Providers) — depends on PR #1
  ├─ 2.1 RED: connectAndSyncProvider tests (depends on 1.2, 1.4)
  ├─ 2.2 ConnectParams + TLS helpers (no deps)
  ├─ 2.3 connectAndSyncProvider (depends on 1.3, 1.4, 2.2)
  ├─ 2.4 Wire into sync_providers.dart (depends on 2.3)
  └─ 2.5 REFACTOR (depends on 2.1-2.4 passing)

PR #3 (UI) — depends on PR #2
  ├─ 3.1 RED: widget tests (depends on 2.3 for provider, 1.3 for state)
  ├─ 3.2 SyncConnectSheet widget (depends on 2.3)
  ├─ 3.3 SyncView connect/results (depends on 1.3, 2.3, 3.2)
  └─ 3.4 REFACTOR (depends on 3.1-3.3 passing)
```
