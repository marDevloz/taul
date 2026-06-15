# Design: Sync Client UI

## Technical Approach

Add client-side sync flow: ConnectView (bottom sheet) → processSyncResponse on SyncCoordinator → provider orchestration → SyncView results. Follows Approach 1 from exploration — minimal, desktop-focused, reuses existing SyncCoordinator symmetry.

## Architecture Decisions

### Decision: processSyncResponse on SyncCoordinator vs separate class

| Option | Tradeoff | Decision |
|--------|----------|----------|
| New `SyncResponseProcessor` | Cleaner separation, more testable, adds a class | Rejected — duplication of ConflictResolver usage logic |
| Method on SyncCoordinator | Reuses existing repo/conflictDao deps, symmetric with handleSyncRequest, ~30 lines | **Chosen** |

**Rationale**: SyncCoordinator already holds `_repo`, `_conflictDao`, `_localDeviceId`. A new class would need the same deps injected. The processSyncResponse logic is 15 lines — not worth a new class. Method name makes the intent clear.

### Decision: TLS fingerprint trust-on-first-use storage

| Option | Tradeoff | Decision |
|--------|----------|----------|
| SharedPreferences (key: `tls_trust_{host}`) | Already used for lastSyncAt, no new dep, survives app restart | **Chosen** |
| Separate SQLite table | Overkill for fingerprint blobs, adds migration | Rejected |
| In-memory only | Lost on restart, user must re-verify every time | Rejected |

**Rationale**: SharedPreferences stores string key → string value. Fingerprints are DER-encoded byte arrays → hex-encode to store. Consistent with existing `sync_last_{peerDeviceId}` pattern in SyncRepositoryImpl.

### Decision: Bottom sheet vs dialog for ConnectView

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Bottom sheet | Consistent with CreateEntrySheet/QuickAddSheet pattern, dismissible | **Chosen** |
| Dialog | Blocks interaction, less natural for multi-field form | Rejected |
| New screen/route | Adds navigation complexity, overkill for 2 fields | Rejected |

**Rationale**: Existing app uses bottom sheets for transient input (create entry, quick add). A 2-field form fits this pattern. SyncView already shows context — sheet overlays without losing it.

### Decision: Connecting state — add to enum vs keep UI-only

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Add `SyncState.connecting` | Exhaustive switches need updating, clear semantics | **Chosen** |
| Reuse `SyncState.syncing` | No enum change, conflates server-sync and client-connect | Rejected |
| UI-only state | Doesn't propagate to SyncService stream, harder to test | Rejected |

**Rationale**: The user experience differs: "connecting" (validating TLS, sending request) vs "syncing" (server processing). SyncService.performSync transitions to syncing internally — but the UI needs to show "Conectando..." before that call. Adding `connecting` as a distinct state keeps the state machine honest and the switch exhaustive (2 lines added per switch).

### Decision: Provider structure — single orchestrator vs split

| Option | Tradeoff | Decision |
|--------|----------|----------|
| Single `connectAndSyncProvider` | One provider to test, sequential flow is natural | **Chosen** |
| Split: connectProvider + processResponseProvider | More granular, but adds coordination overhead | Rejected |

**Rationale**: The client flow is strictly sequential (connect → sync → process → done). A single provider that returns a `ConnectSyncResult` is simpler to reason about and test. Split providers would need shared state between them for no real benefit.

## Data Flow

### Connection Flow (Client Side)

```
SyncView                       ConnectView (Sheet)              Provider
  │                                  │                            │
  │ "Conectar" tap                   │                            │
  │─────────────────────────────────►│                            │
  │                                  │  user fills URL + code     │
  │                                  │  "Conectar" tap            │
  │                                  │───────────────────────────►│
  │                                  │                            │
  │                          ┌───────┴────────┐                   │
  │                          │ connectAndSync │                   │
  │                          │    Provider    │                   │
  │                          └───────┬────────┘                   │
  │                                  │                            │
  │                    ┌─────────────┼─────────────┐              │
  │                    │  1. Parse URL             │              │
  │                    │  2. Check TLS trust       │              │
  │                    │     └─ first time → store │              │
  │                    │     └─ mismatch  → error  │              │
  │                    │  3. getModifiedEntries()  │              │
  │                    │  4. Build SyncRequest     │              │
  │                    │  5. SyncService.performSync()             │
  │                    │  6. processSyncResponse() │              │
  │                    │  7. Return ConnectSyncResult              │
  │                    └─────────────┼─────────────┘              │
  │                                  │                            │
  │  ◄── state: complete ◄──────────┤                            │
  │  show results + conflicts        │                            │
  │                                  │                            │
```

### Response Processing Algorithm

```
processSyncResponse(SyncResponse response):
  1. localDelta = repo.getModifiedEntries(response.serverLastSyncAt)
  2. conflicts = ConflictResolver.detectConflicts(
       localEntries: localDelta,
       remoteEntries: response.entries,
       lastSyncAt: response.serverLastSyncAt,
       peerDeviceId: response.deviceId,
     )
  3. for conflict in conflicts → conflictDao.insert(conflict)
  4. conflictIds = conflicts.map(c.entryId).toSet()
  5. entriesToUpsert = response.entries
       .where(e => !conflictIds.contains(e.id))
  6. if entriesToUpsert.isNotEmpty → repo.upsertEntries(entriesToUpsert)
  7. repo.setLastSyncAt(response.deviceId, response.serverLastSyncAt)
  8. return ProcessResult(entriesUpserted, conflictsCount)
```

### TLS Trust Flow

```
ConnectSyncProvider:
  1. Extract host:port from URL
  2. Get actual fingerprint via SyncClient._getFingerprint(host, port)
  3. storedHex = prefs.getString('tls_trust_$host:$port')
  4. if storedHex == null:
       → store hex(actualFingerprint) as trust_{host:port}
       → proceed (first-time trust)
  5. else if storedHex != hex(actualFingerprint):
       → throw TlsFingerprintMismatchException
       → UI shows: "TLS fingerprint changed! Reject to be safe."
  6. else:
       → proceed (trusted)
```

## Component Specification

### SyncCoordinator.processSyncResponse()

New method on existing `SyncCoordinator`. Same class, same deps.

```dart
Future<ProcessSyncResult> processSyncResponse(SyncResponse response) async {
  final localDelta = await _repo.getModifiedEntries(response.serverLastSyncAt);
  final conflicts = ConflictResolver.detectConflicts(
    localEntries: localDelta,
    remoteEntries: response.entries,
    lastSyncAt: response.serverLastSyncAt,
    peerDeviceId: response.deviceId,
  );
  for (final c in conflicts) { await _conflictDao.insert(c); }
  final conflictIds = conflicts.map((c) => c.entryId).toSet();
  final toUpsert = response.entries.where((e) => !conflictIds.contains(e.id)).toList();
  if (toUpsert.isNotEmpty) { await _repo.upsertEntries(toUpsert); }
  if (response.serverLastSyncAt != null) {
    await _repo.setLastSyncAt(response.deviceId, response.serverLastSyncAt!);
  }
  return ProcessSyncResult(entriesUpserted: toUpsert.length, conflictsCount: conflicts.length);
}
```

### ProcessSyncResult (new freezed class in sync_wire_format.dart)

```dart
@freezed
class ProcessSyncResult with _$ProcessSyncResult {
  const factory ProcessSyncResult({
    required int entriesUpserted,
    required int conflictsCount,
  }) = _ProcessSyncResult;
}
```

### SyncConnectSheet (new widget in sync_connect_sheet.dart)

`ConsumerStatefulWidget`. Two `TextFormField`s (URL, pairing code), one `FilledButton`. Uses `showModalBottomSheet` pattern. On submit: validates non-empty, calls `connectAndSyncProvider`, closes sheet, SyncView shows results.

Widget tree:
```
Scaffold (inside bottom sheet)
  └─ ListView
       ├─ Text("Conectar a dispositivo")
       ├─ TextFormField (URL, hint: "https://192.168.1.x:54321")
       ├─ TextFormField (pairing code, hint: "Código de 6 dígitos")
       ├─ FilledButton("Conectar")
       └─ ErrorText (conditional)
```

### ConnectSyncProvider (new provider in sync_client_providers.dart)

```dart
final connectAndSyncProvider =
    FutureProvider.family<ConnectSyncResult, ConnectParams>((ref, params) async {
  final coordinator = ref.read(syncCoordinatorProvider);
  final service = ref.read(syncServiceProvider);
  final deviceId = await ref.read(deviceIdProvider.future);
  final lastSyncAt = await coordinator.repo.getLastSyncAt(params.peerDeviceId);

  final localDelta = await coordinator.repo.getModifiedEntries(lastSyncAt);
  final request = SyncRequest(
    deviceId: deviceId,
    lastSyncAt: lastSyncAt,
    entries: localDelta,
  );

  ref.read(syncStateProvider.notifier).state = SyncState.connecting;
  final response = await service.performSync(
    host: params.host,
    port: params.port,
    fingerprint: params.fingerprint,
    pairingCode: params.pairingCode,
    request: request,
  );

  final result = await coordinator.processSyncResponse(response);
  ref.read(syncStateProvider.notifier).state = SyncState.complete;
  return result;
});
```

**ConnectParams** (simple class or record):
```dart
class ConnectParams {
  final String host;
  final int port;
  final List<int> fingerprint;
  final String pairingCode;
}
```

### SyncState Enum Change

Add `connecting` between `idle` and `pairing`:

```dart
enum SyncState {
  idle,
  connecting,  // NEW — client validating TLS + sending request
  pairing,
  syncing,
  complete,
  error;

  bool get isActive => this == connecting || this == pairing || this == syncing;
  bool get canStart => this == idle || this == complete || this == error;
  bool get showProgress => this == connecting || this == pairing || this == syncing || this == complete;
}
```

Update `_StatusCard` switch to handle `connecting` case.

### SyncView Modification

Add a "Conectar a dispositivo" card when `syncState == idle || syncState == complete`:

```dart
// After _StatusCard, before _QrSection:
if (syncState.canStart) _ConnectCard(),
```

`_ConnectCard`:
```
Card
  └─ ListTile
       leading: Icon(Icons.link)
       title: Text("Conectar a dispositivo")
       trailing: Icon(Icons.chevron_right)
       onTap: () => showModalBottomSheet(context, SyncConnectSheet)
```

Add a results summary card after sync completes:

```dart
// After _StatusCard:
if (syncState == SyncState.complete) _SyncResultCard(result: lastResult),
```

## File Changes

| File | Action | Description |
|------|--------|-------------|
| `lib/infrastructure/sync/sync_coordinator.dart` | Modify | Add `processSyncResponse()` method (~25 lines) |
| `lib/infrastructure/sync/sync_wire_format.dart` | Modify | Add `ProcessSyncResult` freezed class (~10 lines) |
| `lib/ui/screens/sync_connect_sheet.dart` | Create | Bottom sheet: URL + pairing code input (~90 lines) |
| `lib/ui/providers/sync_client_providers.dart` | Create | `connectAndSyncProvider`, `ConnectParams`, TLS trust helpers (~120 lines) |
| `lib/ui/screens/sync_view.dart` | Modify | Add connect card + results card (~50 lines) |
| `lib/domain/entities/sync_state.dart` | Modify | Add `connecting` state, update `isActive`/`showProgress` (~5 lines) |
| `test/infrastructure/sync/sync_coordinator_test.dart` | Modify | Add `processSyncResponse` tests (~50 lines) |
| `test/ui/screens/sync_view_test.dart` | Modify | Add connect UI + results tests (~40 lines) |

Total: ~120 lines new + ~180 lines modified = ~300 lines (within 400-line budget).

## Interfaces / Contracts

```dart
// New in sync_wire_format.dart
@freezed
class ProcessSyncResult with _$ProcessSyncResult {
  const factory ProcessSyncResult({
    required int entriesUpserted,
    required int conflictsCount,
  }) = _ProcessSyncResult;
}

// New in sync_client_providers.dart
class ConnectParams {
  final String host;
  final int port;
  final List<int> fingerprint;
  final String pairingCode;
  const ConnectParams({
    required this.host,
    required this.port,
    required this.fingerprint,
    required this.pairingCode,
  });
}

// Extended on SyncCoordinator
Future<ProcessSyncResult> processSyncResponse(SyncResponse response);
```

## Testing Strategy

| Layer | What to Test | Approach |
|-------|-------------|----------|
| Unit | `processSyncResponse` — clean upsert, conflict detection, lastSyncAt update | Mock `ISyncRepository` + `ConflictDao`, verify calls. Follows existing `sync_coordinator_test.dart` pattern with mocktail |
| Unit | TLS trust store — first-time accept, match, mismatch | Mock `SharedPreferences`, verify store/check logic |
| Widget | `SyncConnectSheet` — renders fields, validates empty, calls provider | `tester.pumpWidget` with ProviderScope overrides, verify finders |
| Widget | `SyncView` — connect card visible in idle, results card in complete | Extend existing `sync_view_test.dart` with new state overrides |
| Integration | Full client flow — connect → performSync → processResponse | Mock `SyncClient.sync`, verify `processSyncResponse` called with correct `SyncResponse` |

## Migration / Rollout

No migration required. All changes are additive (new method, new files, enum extension). Existing state switches need `connecting` case added — 2-3 lines per switch.

## Open Questions

- [ ] Should TLS trust be host-only (`tls_trust_{host}`) or host+port (`tls_trust_{host:port}`)? Same server on different port = different cert? **Recommendation**: host+port, since the cert is bound to the server instance which includes port.
- [ ] Should `connectAndSyncProvider` be a `FutureProvider.family` (params-driven) or a regular `Provider` returning a function (like `startSyncProvider`)? **Recommendation**: family — params are value types, no need for closure state.
