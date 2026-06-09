# Phase 3 Sync — Technical Design

## 1. Architecture Overview

### Clean Architecture Integration

The sync feature follows existing Clean Architecture layers:

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                             │
│  sync_view.dart, conflict_view.dart, sync_providers.dart   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     Domain Layer                            │
│  conflict.dart (entity), i_sync_repository.dart (interface)│
│  conflict_resolver.dart (service)                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  Infrastructure Layer                       │
│  sync/ (server, client, protocol, certs, pairing)          │
│  database/conflict_dao.dart, conflict_repository_impl.dart │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        Core Layer                           │
│  (constants, errors — no changes needed)                    │
└─────────────────────────────────────────────────────────────┘
```

### Key Design Decisions

1. **HTTP-only (no mDNS)** — Manual IP entry via QR code for MVP; mDNS in Slice 2
2. **Shelf for HTTP server** — Lightweight, already a transitive dependency
3. **Self-signed certs** — Generated per device, trust established during pairing
4. **Delta sync** — Only entries modified since `lastSyncAt`
5. **Conflict detection** — Entry ID + `updatedAt` comparison
6. **DEK never transmitted** — Secrets remain as encrypted blobs over wire

## 2. New Files

### Domain Layer

| File | Key Classes | Dependencies | Lines |
|------|-------------|--------------|-------|
| `lib/domain/entities/conflict.dart` | `Conflict` (freezed) | `entry.dart`, `freezed_annotation` | ~60 |
| `lib/domain/repositories/i_sync_repository.dart` | `ISyncRepository` (abstract) | `conflict.dart`, `entry.dart` | ~30 |
| `lib/domain/services/conflict_resolver.dart` | `ConflictResolver` | `entry.dart`, `conflict.dart` | ~80 |

### Infrastructure Layer

| File | Key Classes | Dependencies | Lines |
|------|-------------|--------------|-------|
| `lib/infrastructure/sync/sync_server.dart` | `SyncServer` | `shelf`, `shelf_io`, `certificate_manager.dart` | ~150 |
| `lib/infrastructure/sync/sync_client.dart` | `SyncClient` | `http`, `certificate_manager.dart` | ~120 |
| `lib/infrastructure/sync/sync_protocol.dart` | `SyncRequest`, `SyncResponse`, `PairingRequest` | `json_serializable`, `entry.dart` | ~100 |
| `lib/infrastructure/sync/certificate_manager.dart` | `CertificateManager` | `dart:io`, `crypto` | ~100 |
| `lib/infrastructure/sync/pairing_manager.dart` | `PairingManager` | `dart:math` | ~80 |
| `lib/infrastructure/sync/sync_repository_impl.dart` | `SyncRepositoryImpl` | `i_sync_repository.dart`, `conflict_dao.dart`, `entry_dao.dart` | ~150 |
| `lib/infrastructure/database/conflict_dao.dart` | `ConflictDao` | `app_database.dart`, `drift` | ~100 |

### UI Layer

| File | Key Classes | Dependencies | Lines |
|------|-------------|--------------|-------|
| `lib/ui/screens/sync_view.dart` | `SyncView` (ConsumerWidget) | `sync_providers.dart`, `mobile_scanner`, `qr_flutter` | ~250 |
| `lib/ui/screens/conflict_view.dart` | `ConflictView` (ConsumerWidget) | `sync_providers.dart`, `entry.dart` | ~200 |
| `lib/ui/providers/sync_providers.dart` | `SyncNotifier`, `ConflictListNotifier` | `sync_repository_impl.dart`, `conflict_resolver.dart` | ~150 |

**Total new files**: 13  
**Estimated total lines**: ~1,570

## 3. Modified Files

| File | Changes | Lines Added |
|------|---------|-------------|
| `lib/infrastructure/database/app_database.dart` | Add `Conflicts` table, migration v11 | ~40 |
| `lib/infrastructure/database/conflicts_table.dart` | New Drift table definition | ~20 |
| `lib/app.dart` | Add `/sync` and `/conflict` routes | ~15 |
| `lib/ui/screens/home_view.dart` | Wire sync button to `SyncView` | ~5 |
| `pubspec.yaml` | Add `shelf`, `shelf_io`, `http`, `qr_flutter`, `mobile_scanner` | ~6 |

**Total modified files**: 5  
**Estimated lines added**: ~86

## 4. Data Model

### New Table: `Conflicts`

```dart
class Conflicts extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get entryId => text()(); // References entries.id
  TextColumn get localVersion => text()(); // JSON of local Entry
  TextColumn get remoteVersion => text()(); // JSON of remote Entry
  TextColumn get remoteDeviceId => text()(); // Device ID of remote
  TextColumn get resolution => text().nullable()(); // local/remote/both/null
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn? get resolvedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

### New Columns in `Entries` (None for MVP)

The existing `Entries` table already has `version` and `updatedAt` needed for conflict detection. No new columns needed for MVP.

### New SharedPreferences Keys

- `device_id`: UUID of this device (generated once)
- `last_sync_at_{paired_device_id}`: ISO8601 timestamp of last successful sync with each paired device

## 5. Sync Protocol

### HTTP Endpoints

**Server (Device A)**:
- `POST /sync` — Receive sync request from Device B
- `POST /pairing/validate` — Validate pairing code during handshake

**Client (Device B)**:
- `POST https://{ip}:{port}/sync` — Send sync request to Device A
- `POST https://{ip}:{port}/pairing/validate` — Send pairing code

### JSON Wire Format

#### SyncRequest
```json
{
  "deviceId": "uuid-of-sender",
  "lastSyncAt": "2026-06-08T22:00:00Z",
  "entries": [
    {
      "id": "entry-uuid",
      "type": "note",
      "title": "My Note",
      "content": "Content...",
      "metadata": {"key": "value"},
      "tags": ["tag1", "tag2"],
      "encryptedSecret": "base64-blob",  // Never decrypted
      "cipherNonce": "base64-nonce",
      "cipherTag": "base64-tag",
      "createdAt": "2026-06-08T20:00:00Z",
      "updatedAt": "2026-06-08T22:00:00Z",
      "version": 1,
      "deletedAt": null,
      "completedAt": null
    }
  ]
}
```

#### SyncResponse
```json
{
  "deviceId": "uuid-of-responder",
  "entries": [...],
  "conflicts": [
    {
      "entryId": "entry-uuid",
      "localUpdatedAt": "2026-06-08T21:00:00Z",
      "remoteUpdatedAt": "2026-06-08T22:00:00Z"
    }
  ]
}
```

### TLS Setup

1. **Certificate Generation**: Each device generates self-signed X.509 cert on first launch
2. **Storage**: Cert + private key stored in app documents directory (encrypted with DEK on desktop)
3. **Trust**: Pairing code validates cert fingerprint — trust established during pairing
4. **Handshake**: TLS 1.2+ only, strong cipher suites

### Pairing Flow

1. Device A: Start HTTPS server on random port, show QR code with `ip:port`
2. Device B: Scan QR, connect to `https://{ip}:{port}`
3. Device A: Generate 6-digit code, display to user
4. Device B: Enter code, send `PairingRequest` to `POST /pairing/validate`
5. Device A: Validate code, return `PairingResponse` with session token
6. Both devices: Exchange modified entries via `POST /sync`

## 6. State Management

### New Providers

```dart
// Sync state
enum SyncStatus { idle, discovering, pairing, syncing, error, success }

class SyncState {
  final SyncStatus status;
  final String? remoteDeviceId;
  final int entriesSynced;
  final String? errorMessage;
}

class SyncNotifier extends StateNotifier<SyncState> {
  // Methods: startServer, connectToDevice, sendSyncRequest, cancel
}

// Conflict state
class ConflictListNotifier extends StateNotifier<List<Conflict>> {
  // Methods: loadConflicts, resolveConflict, dismissConflict
}

// Providers
final syncProvider = StateNotifierProvider<SyncNotifier, SyncState>(...);
final conflictListProvider = StateNotifierProvider<ConflictListNotifier, List<Conflict>>(...);
final pendingConflictCountProvider = Provider<int>((ref) {
  // Count unresolved conflicts
});
```

## 7. Navigation

### New Routes

```dart
GoRoute(
  path: '/sync',
  name: 'sync',
  builder: (_, __) => const SyncView(),
),
GoRoute(
  path: '/conflict',
  name: 'conflict',
  builder: (_, __) => const ConflictView(),
),
```

### Modified Navigation

- `home_view.dart`: Sync button `onPressed` → `context.push('/sync')`

## 8. PR Breakdown (Chained PRs ≤400 lines each)

### PR 1: Domain Layer + Migration (~180 lines)
- `lib/domain/entities/conflict.dart`
- `lib/domain/repositories/i_sync_repository.dart`
- `lib/infrastructure/database/conflicts_table.dart`
- `lib/infrastructure/database/conflict_dao.dart`
- Migration v11 in `app_database.dart`
- Unit tests for `ConflictResolver`

### PR 2: Sync Protocol + Certificate Management (~350 lines)
- `lib/infrastructure/sync/sync_protocol.dart`
- `lib/infrastructure/sync/certificate_manager.dart`
- `lib/infrastructure/sync/pairing_manager.dart`
- Unit tests for protocol serialization, cert generation

### PR 3: Sync Server + Client (~300 lines)
- `lib/infrastructure/sync/sync_server.dart`
- `lib/infrastructure/sync/sync_client.dart`
- `lib/infrastructure/sync/sync_repository_impl.dart`
- Integration tests for server/client handshake

### PR 4: Providers + UI (~400 lines)
- `lib/ui/providers/sync_providers.dart`
- `lib/ui/screens/sync_view.dart`
- `lib/ui/screens/conflict_view.dart`
- Modifications to `app.dart` (routes), `home_view.dart` (button wiring)
- Widget tests for screens

### PR 5: Polish + Edge Cases (~150 lines)
- Error handling improvements
- Loading states, empty states
- Documentation updates
- Final integration tests

## 9. Migration Strategy (v11)

```dart
if (from < 11) {
  await m.createTable(conflicts);
}
```

**Steps**:
1. Create `conflicts` table with all columns
2. No data migration needed (new table only)
3. No columns added to existing tables for MVP
4. Test migration on both desktop (SQLCipher) and Android (system SQLite)

## 10. Error Handling

### Failure Modes & Mitigations

| Failure | Detection | User Feedback | Recovery |
|---------|-----------|---------------|----------|
| **Server start fails** (port in use) | `SocketException` | "Port in use, retrying..." | Auto-retry with different port |
| **Client connection fails** | `SocketException` / timeout | "Cannot connect to device" | Show troubleshooting tips |
| **Pairing code invalid** | HTTP 401 | "Invalid code, try again" | Re-enter code |
| **Certificate mismatch** | TLS handshake error | "Security error" | Re-pair devices |
| **Sync conflict detected** | Conflict list non-empty | Badge on conflict icon | Open ConflictView |
| **Large vault timeout** | HTTP timeout | "Sync taking long..." | Increase timeout, show progress |
| **Network interruption** | `SocketException` | "Connection lost" | Resume on reconnect |
| **JSON parse error** | `FormatException` | "Data corrupted" | Skip malformed entries |

### Error States

```dart
enum SyncError {
  serverStartFailed,
  connectionFailed,
  pairingFailed,
  certificateError,
  syncTimeout,
  dataCorruption,
  conflictDetected,
}
```

## 11. Security Considerations

### DEK Handling
- **NEVER transmitted over wire** — each device decrypts with its own DEK
- Encrypted secrets travel as opaque base64 blobs
- Remote device cannot decrypt without local DEK

### Certificate Trust
- Self-signed cert generated per device
- Fingerprint displayed during pairing
- Pairing code validates fingerprint match
- No certificate authority needed

### Pairing Code
- 6-digit numeric code (1M combinations)
- Valid for single pairing session only
- Regenerated on each new pairing attempt
- Time-limited (5 minutes)

### TLS Configuration
- TLS 1.2+ only
- Strong cipher suites (AES-256-GCM, ChaCha20-Poly1305)
- Certificate pinning after first successful pairing

### Threat Model (MVP)
- ✅ Man-in-the-middle prevented by pairing code validation
- ✅ Eavesdropping prevented by TLS
- ✅ Secrets protected by DEK encryption
- ⚠️ At-rest encryption gap on Android (no SQLCipher) — documented accepted risk
- ⚠️ Single device pair only — no mesh network security concerns

## Appendix: Dependencies

### New Packages

```yaml
dependencies:
  shelf: ^1.4.0
  shelf_io: ^1.4.0
  http: ^1.2.0
  qr_flutter: ^4.1.0
  mobile_scanner: ^5.0.0
```

### Existing Packages Used

- `crypto` — Certificate generation (transitive dependency)
- `dart:io` — Socket, SecurityContext
- `dart:math` — Pairing code generation
- `dart:convert` — JSON serialization