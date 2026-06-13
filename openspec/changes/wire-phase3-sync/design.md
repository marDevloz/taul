# Design: Wire Phase 3 Sync

## Architecture

This change connects existing infrastructure into a working sync flow. The key addition is `SyncCoordinator`, which implements the missing `onRequest` handler and orchestrates the bidirectional sync.

```
┌──────────────────┐     POST /sync      ┌──────────────────┐
│   Device A       │ ◄─────────────────► │   Device B       │
│  SyncServer      │     SyncRequest/     │  SyncClient      │
│  (listening)     │     SyncResponse     │  (connects)      │
└──────┬───────────┘                      └────────┬─────────┘
       │                                           │
       │ onRequest                                  │ performSync
       ▼                                           ▼
┌──────────────────┐                      ┌──────────────────┐
│ SyncCoordinator   │                     │ SyncCoordinator   │
│ (NEW)             │                     │ (on B side too)   │
├──────────────────┤                      ├──────────────────┤
│ 1. Receive       │                      │ 1. Get local     │
│    remote entries │                     │    delta entries  │
│ 2. Load local    │                      │ 2. Send request  │
│    delta via     │                      │ 3. Receive       │
│    Repo          │                      │    response      │
│ 3. Detect        │                      │ 4. Upsert remote │
│    conflicts     │                      │    entries       │
│ 4. Store         │                      │ 5. Store         │
│    conflicts     │                      │    conflicts     │
│ 5. Upsert non-   │                      │ 6. Update        │
│    conflicting   │                      │    lastSyncAt    │
│ 6. Return delta  │                      │                  │
│    + conflict    │                      │                  │
│    count         │                      │                  │
└──────┬───────────┘                      └────────┬─────────┘
       │                                           │
       ▼                                           ▼
┌──────────────────┐                      ┌──────────────────┐
│ SyncRepository   │                      │ SyncRepository   │
│ Impl             │                      │ Impl             │
│ - getModified    │                      │ - upsertEntries  │
│   Entries()      │                      │ - getConflicts() │
│ - upsertEntries()│                      │ - setLastSyncAt()│
│ - setLastSyncAt()│                      │                  │
└──────────────────┘                      └──────────────────┘
```

## Component Design

### SyncCoordinator

```dart
class SyncCoordinator {
  final ISyncRepository _repo;
  final ConflictDao _conflictDao;
  final Logger _log;

  /// Called by SyncServer when a POST /sync arrives.
  Future<SyncResponse> handleSyncRequest(SyncRequest request) async {
    // 1. Load local entries modified since remote's lastSyncAt
    final localDelta = await _repo.getModifiedEntries(request.lastSyncAt);

    // 2. Map remote entries by ID for conflict detection
    final remoteMap = {for (final e in request.entries) e.id: e};

    // 3. Detect conflicts: entries modified on BOTH sides
    final localMap = {for (final e in localDelta) e.id: e};
    final conflicts = ConflictResolver.detectConflicts(
      localEntries: localDelta,
      remoteEntries: request.entries,
      lastSyncAt: request.lastSyncAt,
      peerDeviceId: request.deviceId,
    );

    // 4. Store conflicts
    for (final conflict in conflicts) {
      await _conflictDao.insert(conflict);
    }

    // 5. Upsert non-conflicting remote entries
    final conflictIds = conflicts.map((c) => c.entryId).toSet();
    final entriesToUpsert = request.entries
        .where((e) => !conflictIds.contains(e.id))
        .toList();
    if (entriesToUpsert.isNotEmpty) {
      await _repo.upsertEntries(entriesToUpsert);
    }

    // 6. Record sync timestamp
    final now = DateTime.now();
    // Server side: set lastSyncAt for this peer
    await _repo.setLastSyncAt(request.deviceId, now);

    // 7. Return response with local delta + conflict count
    return SyncResponse(
      deviceId: /* local device ID */,
      entriesReceived: request.entries.length,
      conflictsCount: conflicts.length,
      serverLastSyncAt: now,
    );
  }
}
```

### SyncService Wiring

```dart
// In sync_providers.dart, replace null with real service:
final certificateManagerProvider = Provider<CertificateManager>((ref) {
  return CertificateManager.create();
});

final syncServerProvider = Provider<SyncServer>((ref) {
  final cert = ref.watch(certificateManagerProvider);
  final coordinator = ref.watch(syncCoordinatorProvider);
  return SyncServer(
    certManager: cert,
    pairingCode: ref.watch(pairingCodeProvider),
    onRequest: coordinator.handleSyncRequest,
  );
});

final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  final repo = ref.watch(syncRepositoryProvider);
  final db = ref.watch(databaseProvider);
  return SyncCoordinator(
    repo: repo,
    conflictDao: ConflictDao(db),
  );
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final server = ref.watch(syncServerProvider);
  final client = SyncClient();
  final deviceId = ref.watch(deviceIdProvider).valueOrNull ?? 'unknown';
  return SyncService(
    server: server,
    client: client,
    deviceId: deviceId,
    onRequest: ref.watch(syncCoordinatorProvider).handleSyncRequest,
  );
});
```

### SyncView QR

```dart
// In sync_view.dart, replace hardcoded QR:
final ip = await PairingService().getLocalIpAddress();
final port = server.port!; // from SyncServer
final code = pairingService.generateCode();
final qrData = 'https://$ip:$port';

QrImageView(
  data: qrData,
  version: QrVersions.auto,
  size: 160,
)
// Display code below QR:
Text('Código: $code',
  style: TextStyle(fontFamily: 'monospace', fontSize: 24),
)
```

## Data Flow

### Sync Initiation (Device A starts server, Device B connects)

1. User taps "Start Sync" on Device A
2. SyncService.startServer() → SyncServer starts on random port
3. PairingService.generateCode() → 6-digit code
4. PairingService.getLocalIpAddress() → local IP
5. SyncView shows QR with `https://<ip>:<port>` and 6-digit code
6. User on Device B scans QR (or manually enters URL)
7. Device B opens connection to `https://<ip>:<port>`

### Sync Exchange (bidirectional)

1. Device B gathers local delta via SyncRepositoryImpl.getModifiedEntries(lastSyncAt)
2. Device B sends SyncRequest to Device A
3. Device A's SyncServer receives POST /sync
4. SyncServer validates X-Pairing-Code header
5. SyncCoordinator.handleSyncRequest() processes:
   a. Load local delta from DB
   b. Detect conflicts via ConflictResolver
   c. Store conflicts in ConflictDao
   d. Upsert non-conflicting remote entries
   e. Set lastSyncAt for peer
   f. Return SyncResponse with local delta + conflictsCount
6. Device B receives SyncResponse
7. Device B upserts non-conflicting entries from response
8. Device B stores conflicts from response
9. Device B updates lastSyncAt for Device A
10. Both devices show "Sync complete — N entries, M conflicts"

## State Management

```
SyncState: idle → pairing → syncing → complete / error
                ↓
        QR displayed
        + code shown
```

- **idle**: Server not running. "Start Sync" button visible.
- **pairing**: Server running, QR + code displayed. Waiting for remote connection.
- **syncing**: Remote connected, entries being exchanged. Progress shown.
- **complete**: Sync finished. Summary shown. Auto-returns to idle after 3s.
- **error**: Sync failed. Error message. Auto-recovers to idle after 5s.

## Security

- TLS with self-signed cert: already implemented
- Pairing code validation: already implemented (X-Pairing-Code header)
- Protected entries: transmitted as opaque blobs (encryptedSecret, cipherNonce, cipherTag)
- DEK never transmitted: enforced by architecture
- No cleartext secrets over the wire: existing design

## File Changes

| File | Change |
|------|--------|
| `lib/infrastructure/sync/sync_coordinator.dart` | **Create** — 80 lines |
| `lib/ui/providers/sync_providers.dart` | **Modify** — wire real SyncService with deps (~30 lines changed) |
| `lib/ui/screens/sync_view.dart` | **Modify** — dynamic QR + pairing code display (~20 lines changed) |
| `lib/infrastructure/sync/sync_repository_impl.dart` | **Verify** tagsColors serialization (minor, ~5 lines) |
| `test/infrastructure/sync/sync_integration_test.dart` | **Create** — E2E sync test (~150 lines) |

Total estimated: ~285 lines (within 400-line budget)
