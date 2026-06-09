# Proposal: Phase 3 — Device-to-Device Sync

## Intent

Taúl is a single-device vault today. Users who own multiple devices (phone + laptop, or desktop + tablet) have no way to keep entries in sync. Phase 3 adds peer-to-peer sync so two devices on the same network can exchange modified entries, detect conflicts, and let users resolve them.

## Scope

### In Scope
- HTTP-only sync server/client (shelf + TLS self-signed cert)
- Manual device pairing: QR code for `ip:port`, 6-digit pairing code for auth
- Delta sync: only entries modified since `lastSyncAt`
- Conflict detection: entry ID + `updatedAt` — if both modified since last sync, create conflict record
- Conflict resolution UI: keep local, keep remote, or keep both
- Database migration v11: `conflicts` table, `last_sync_at` tracking
- SyncView screen: start sync, show status, show conflict count
- ConflictView screen: side-by-side diff, pick resolution

### Out of Scope
- mDNS auto-discovery (Slice 2 — platform-native, needs `nsd_android`/`multicast_dns`)
- Background sync service (manual trigger only for MVP)
- Multi-device mesh (only 2-device pairs for MVP)
- Cloud relay / internet sync
- Real-time push notifications

## Capabilities

### New Capabilities
- `sync-protocol`: HTTP server/client, TLS, pairing code, JSON wire format
- `conflict-resolution`: Conflict entity, detection, resolution UI, persistence

### Modified Capabilities
- None — this is additive infrastructure with no changes to existing spec behavior

## Approach

**Option C from exploration: HTTP-only, manual pairing.** Device A starts HTTPS server on random port, shows QR code with `ip:port`. Device B scans QR, connects, enters 6-digit code shown on A. On success: exchange modified entries since `lastSyncAt`, store timestamp. Conflicts go to `conflicts` table, resolved via ConflictView.

Wire format:
```json
{
  "deviceId": "uuid",
  "lastSyncAt": "ISO8601",
  "entries": [...]
}
```

Secrets travel as opaque DEK-encrypted blobs — never decrypted over the wire.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/infrastructure/sync/` | New | Protocol, server, client, cert management |
| `lib/domain/entities/conflict.dart` | New | Conflict entity |
| `lib/domain/repositories/i_sync_repository.dart` | New | Sync repository interface |
| `lib/domain/services/conflict_resolver.dart` | New | Conflict detection + resolution |
| `lib/ui/screens/sync_view.dart` | New | Sync main screen |
| `lib/ui/screens/conflict_view.dart` | New | Conflict resolution screen |
| `lib/ui/providers/sync_providers.dart` | New | Riverpod providers for sync state |
| `lib/infrastructure/database/app_database.dart` | Modified | Migration v11, conflicts table |
| `lib/app.dart` | Modified | Add sync route |
| `lib/ui/screens/home_view.dart` | Modified | Wire sync button |
| `pubspec.yaml` | Modified | Add shelf, shelf_io, http, qr_flutter, mobile_scanner |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Android at-rest encryption gap (no SQLCipher) | High | Document limitation; secrets encrypted over wire via DEK blobs; at-rest risk accepted for MVP |
| Self-signed cert trust on first connect | Medium | Pairing code validates cert fingerprint — trust established during pairing |
| Concurrent sync attempts | Medium | Simple lock — only one sync session at a time per device |
| Large vault performance | Low | Delta sync only (changed entries); consider zstd compression in Slice 2 |

## Rollback Plan

- All sync code lives in `infrastructure/sync/` — delete folder + remove providers + remove route
- Migration v11 adds `conflicts` table only — drop table to revert
- No changes to existing entity or repository behavior — zero regression risk to current functionality

## Dependencies

- `shelf`, `shelf_io` — HTTP server
- `http` — HTTP client
- `qr_flutter` — QR code display
- `mobile_scanner` — QR code scanning
- Dart `crypto` — self-signed cert generation (already transitive dep)

## Success Criteria

- [x] Two devices on same WiFi can pair via QR + 6-digit code
- [x] Modified entries sync bidirectionally after pairing
- [x] Conflicts are detected when both devices modify same entry
- [x] ConflictView lets user pick local/remote/both resolution
- [x] Vault must be UNLOCKED to initiate sync
- [x] Secrets never transmitted as cleartext over the wire
