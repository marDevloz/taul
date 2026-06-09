# Tasks: Phase 3 — Device-to-Device Sync

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1265 (across 5 PRs) |
| 400-line budget risk | Medium |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 → PR 2 → PR 3 → PR 4 → PR 5 |
| Delivery strategy | auto-chain |
| Chain strategy | stacked-to-main |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: stacked-to-main
400-line budget risk: Medium

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Domain layer + DB migration | PR 1 | ~180 lines. Foundation for all sync code. |
| 2 | Sync protocol (TLS, HTTP) | PR 2 | ~295 lines. Server + client + cert management. |
| 3 | Sync service + pairing | PR 3 | ~200 lines. Orchestration + delta sync logic. |
| 4 | UI screens + providers | PR 4 | ~370 lines. Largest PR — may need split. |
| 5 | Polish + integration tests | PR 5 | ~220 lines. Edge cases, error handling, tests. |

**PR #4 risk**: At ~370 lines it approaches the 400-line budget. Consider splitting SyncView and ConflictView into separate PRs if review load is a concern.

---

## PR #1: Domain Layer + DB Migration (~180 lines)

- [x] 1.1 Create `lib/domain/entities/conflict.dart` — freezed entity with fields: id, entryId, localVersion (Entry), remoteVersion (Entry), resolution (enum), peerDeviceId, createdAt, resolvedAt. Run build_runner for .freezed.dart + .g.dart.
- [x] 1.2 Create `lib/domain/entities/conflict_resolution.dart` — enum: PENDING, KEEP_LOCAL, KEEP_REMOTE, KEEP_BOTH.
- [x] 1.3 Create `lib/domain/entities/sync_state.dart` — enum: idle, pairing, syncing, complete, error. Freezed union if needed.
- [x] 1.4 Create `lib/domain/repositories/i_sync_repository.dart` — abstract interface: getModifiedEntries(lastSyncAt), upsertEntries(entries), getConflicts(), resolveConflict(id, resolution), getLastSyncAt(peerDeviceId), setLastSyncAt(peerDeviceId, timestamp).
- [x] 1.5 Create `lib/domain/services/conflict_resolver.dart` — detectConflicts(local, remote, lastSyncAt) returns List<Conflict>; resolveConflict(conflict, resolution) applies choice.
- [x] 1.6 Create `lib/infrastructure/database/conflicts_table.dart` — Drift table class for `conflicts` with columns: id, entryId, localVersion, remoteVersion, resolution, peerDeviceId, createdAt, resolvedAt. Add indexes on entryId and resolution.
- [x] 1.7 Create `lib/infrastructure/database/conflict_dao.dart` — Drift DAO: insert, updateResolution, getByResolution, getByEntryId, getPendingCount.
- [x] 1.8 Modify `lib/infrastructure/database/app_database.dart` — Add Conflicts to @DriftDatabase tables, bump schemaVersion to 11, add migration v11 in onUpgrade (create conflicts table), add to onCreate.
- [x] 1.9 Create `test/infrastructure/database/migration_v11_test.dart` — Test migration from v10 to v11 creates conflicts table with correct schema.
- [x] 1.10 Create `test/domain/entities/conflict_test.dart` — Test Conflict entity serialization, resolution enum values.

**Files created:** conflict.dart, conflict.freezed.dart, conflict.g.dart, conflict_resolution.dart, sync_state.dart, i_sync_repository.dart, conflict_resolver.dart, conflicts_table.dart, conflict_dao.dart, conflict_dao.g.dart
**Files modified:** app_database.dart, app_database.g.dart
**Tests:** migration_v11_test.dart, conflict_test.dart

---

## PR #2: Sync Protocol — TLS, HTTP Server/Client (~295 lines)

- [x] 2.1 Create `lib/infrastructure/sync/certificate_manager.dart` — Generate self-signed X.509 cert (RSA 2048, SHA-256), store as sync_cert.pem + sync_key.pem in app documents dir, load existing cert, validate cert not expired, regenerate if corrupt.
- [x] 2.2 Create `lib/infrastructure/sync/sync_server.dart` — Shelf HTTPS server on random port (49152–65535), single POST /sync endpoint, validate pairing code via X-Pairing-Code header, return 401 on bad code, 429 on concurrent request, auto-shutdown after 5 min inactivity.
- [x] 2.3 Create `lib/infrastructure/sync/sync_client.dart` — HTTP client using `http` package, connect to remote HTTPS server, validate TLS fingerprint from pairing, 10s connect / 30s read timeout, handle 200/401/409/429/5xx responses, chunked send for 100+ entries.
- [x] 2.4 Create `lib/infrastructure/sync/sync_wire_format.dart` — SyncRequest/SyncResponse models with JSON serialization: deviceId, lastSyncAt, entries[], conflictsCount. Entry JSON maps all Entry fields.
- [x] 2.5 Add dependencies to `pubspec.yaml` — shelf, shelf_io, http, qr_flutter, mobile_scanner.
- [x] 2.6 Create `test/infrastructure/sync/certificate_manager_test.dart` — Test cert generation, loading, regeneration on corrupt file.
- [x] 2.7 Create `test/infrastructure/sync/sync_wire_format_test.dart` — Test SyncRequest/SyncResponse JSON roundtrip.

**Files created:** certificate_manager.dart, sync_server.dart, sync_client.dart, sync_wire_format.dart
**Files modified:** pubspec.yaml
**Tests:** certificate_manager_test.dart, sync_wire_format_test.dart

---

## PR #3: Sync Service — Pairing + Delta Sync (~200 lines)

- [x] 3.1 Create `lib/infrastructure/sync/pairing_service.dart` — Generate 6-digit cryptographically random code, validate code with 3-attempt lockout, generate QR data (https://ip:port), detect local IP address.
- [x] 3.2 Create `lib/infrastructure/sync/sync_service.dart` — Orchestrate full sync flow: startServer → showQR → waitForPair → exchangeEntries → detectConflicts → updateLastSyncAt. Expose stream of SyncState transitions. Handle errors → state = ERROR → auto-recover to idle.
- [x] 3.3 Create `lib/infrastructure/sync/sync_repository_impl.dart` — Implement ISyncRepository: query entries with updatedAt > lastSyncAt, upsert remote entries, store conflicts, manage lastSyncAt in SharedPreferences (key: sync_last_<peerDeviceId>).
- [x] 3.4 Create `lib/ui/providers/device_id_provider.dart` — Riverpod provider: load/generate UUID v4 from SharedPreferences key device_id, expose as AsyncProvider.
- [x] 3.5 Create `test/infrastructure/sync/pairing_service_test.dart` — Test code generation (6 digits, random), validation, lockout after 3 failures.
- [x] 3.6 Create `test/infrastructure/sync/sync_service_test.dart` — Test sync flow state transitions, error recovery, delta sync filtering.

**Files created:** pairing_service.dart, sync_service.dart, sync_repository_impl.dart, device_id_provider.dart
**Tests:** pairing_service_test.dart, sync_service_test.dart

---

## PR #4: UI — SyncView, ConflictView, Providers, Routes (~370 lines)

- [x] 4.1 Create `lib/ui/providers/sync_providers.dart` — Riverpod providers: syncStateProvider (StateProvider<SyncState>), conflictCountProvider (StreamProvider<int>), startSyncProvider, stopSyncProvider, resolveConflictProvider.
- [x] 4.2 Create `lib/ui/screens/sync_view.dart` — Main sync screen: device ID display, Start/Stop button, QR code (qr_flutter), 6-digit pairing code, status indicator (idle/connecting/syncing/complete/error), conflict count badge tapping → ConflictView. Vault LOCKED → show "Unlock vault to sync".
- [x] 4.3 Create `lib/ui/screens/conflict_view.dart` — Conflict list (ListView of cards), tap → detail with side-by-side diff (title, content, tags, metadata). Three buttons: Keep Local, Keep Remote, Keep Both. "Keep Both" creates conflict_<id>_<ts> entry. "Resolve All" with strategy picker. Truncate diff at 5000 chars with "Show more".
- [x] 4.4 Modify `lib/app.dart` — Add `/sync` route under ShellRoute with SyncView destination. Add import.
- [x] 4.5 Modify `lib/ui/screens/home_view.dart:511` — Replace SnackBar with `context.push('/sync')`. Add import.
- [x] 4.6 Create `test/ui/screens/sync_view_test.dart` — Widget test: renders device ID, start button, locked state message.
- [x] 4.7 Create `test/ui/screens/conflict_view_test.dart` — Widget test: renders conflict list, resolution buttons.

**Files created:** sync_providers.dart, sync_view.dart, conflict_view.dart
**Files modified:** app.dart, home_view.dart
**Tests:** sync_view_test.dart, conflict_view_test.dart

---

## PR #5: Polish — Error Handling, Edge Cases, Integration Tests (~220 lines)

- [x] 5.1 Add error handling to sync_server.dart — Port-in-use retry (5 attempts), cert generation failure → show error, server crash → auto-restart once.
- [x] 5.2 Add error handling to sync_client.dart — Server disappears mid-sync → "Sync interrupted", large payload chunking (100 entries/request), connection retry logic.
- [x] 5.3 Add edge cases to sync_service.dart — Clock skew handling (server timestamp authoritative), app backgrounded < 30s continues, > 30s aborts, navigation away auto-stops server.
- [x] 5.4 Add edge cases to conflict_view.dart — Deleted locally → badge + only "Keep Remote" active, deleted remotely → badge + only "Keep Local" active, user exits without resolving → conflicts remain PENDING.
- [x] 5.5 Create `test/integration/sync_integration_test.dart` — End-to-end: two in-memory DBs, start server on one, client connects, entries sync bidirectionally, conflicts detected, resolved via Keep Local/Remote/Both.
- [x] 5.6 Create `test/infrastructure/sync/sync_server_test.dart` — Test server start/stop, 401 on bad code, 429 on concurrent request, auto-shutdown timeout.
- [x] 5.7 Create `test/infrastructure/sync/sync_client_test.dart` — Test client connection, timeout handling, chunked send, response processing.
- [x] 5.8 Add VaultState extensions to sync_state.dart — PAIRING, SYNCING states with UI-visible transitions.

**Files created:** sync_integration_test.dart, sync_server_test.dart, sync_client_test.dart
**Files modified:** sync_server.dart, sync_client.dart, sync_service.dart, conflict_view.dart, sync_state.dart
**Tests:** 3 new test files

---

## Task Dependency Graph

```
PR #1 (Domain + DB)
  ├─ 1.1-1.5: Domain entities, interfaces, services (no deps)
  ├─ 1.6-1.8: DB table, DAO, migration (depends on 1.1 for Conflict type)
  └─ 1.9-1.10: Tests (depends on 1.6-1.8)

PR #2 (Protocol) — depends on PR #1
  ├─ 2.1: Certificate manager (no deps within PR)
  ├─ 2.2: Sync server (depends on 2.1)
  ├─ 2.3: Sync client (depends on 2.1)
  └─ 2.4: Wire format (depends on 1.1 for Entry type)

PR #3 (Service) — depends on PR #1 + PR #2
  ├─ 3.1: Pairing service (depends on 2.2 for server IP/port)
  ├─ 3.2: Sync service (depends on 2.2, 2.3, 3.1)
  └─ 3.3: Repository impl (depends on 1.4, 1.7)

PR #4 (UI) — depends on PR #3
  ├─ 4.1: Providers (depends on 3.2, 1.3)
  ├─ 4.2: SyncView (depends on 4.1, 2.4)
  └─ 4.3: ConflictView (depends on 4.1, 1.1)

PR #5 (Polish) — depends on PR #4
  └─ 5.1-5.8: Error handling, edge cases, integration tests
```
