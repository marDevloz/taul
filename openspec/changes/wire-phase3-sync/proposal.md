# Proposal: Wire Phase 3 Sync

## Intent

Phase 3 sync was spec'd and its infrastructure built (server, client, certs, pairing, conflict detection, UI), but the orchestration that connects all pieces was never implemented. SyncService is never instantiated, the QR code is hardcoded, and no real sync flow exists. This change wires everything together to make device-to-device sync actually work.

## Scope

### In Scope
- SyncCoordinator that orchestrates the full sync flow (receive entries → detect conflicts → return delta)
- Wire SyncService with real dependencies in providers
- Real QR code with local IP + port + 6-digit pairing code
- Crypto policy for protected entries (opaque blob transfer, same-DEK detection)
- Integration test for end-to-end sync (two in-memory DBs)
- tagsColors included in sync payload

### Out of Scope
- Domain layer refactor (sync logic stays in infrastructure)
- mDNS auto-discovery (deferred from original spec)
- Background/periodic sync (manual trigger only)
- Multi-device mesh (2-device pairs only)
- Cloud relay / internet sync
- "Resolve All" batch in ConflictView

## Capabilities

### New Capabilities
- `sync-orchestration`: Full sync flow coordinator — entry exchange, conflict detection during sync, delta response

### Modified Capabilities
- `sync-protocol`: onRequest handler now processes real entries instead of being a stub
- `sync-pairing`: QR code is now dynamic with real IP:port + pairing code
- `sync-security`: Crypto policy for cross-device protected entries (opaque blob transfer, DEK matching detection)

## Approach

Create a `SyncCoordinator` class that implements the `onRequest` callback for `SyncServer`. When remote entries arrive:
1. Load local entries modified since lastSyncAt via SyncRepositoryImpl
2. Detect conflicts via ConflictResolver (both sides modified)
3. Store conflicts in ConflictDao
4. Return local delta + conflict count to remote client
5. Upsert incoming non-conflicting entries

Wire SyncService in providers with CertificateManager, SyncServer, SyncClient, SyncRepositoryImpl, and the new SyncCoordinator.

Generate QR data from PairingService.getLocalIpAddress() + server.port, display the pairing code.

Protected entries: encrypted secrets travel as opaque blobs (encryptedSecret, cipherNonce, cipherTag). If DEK doesn't match (different master password), show placeholder on recipient.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/infrastructure/sync/sync_coordinator.dart` | New | Full sync flow orchestrator |
| `lib/ui/providers/sync_providers.dart` | Modified | Wire real SyncService |
| `lib/ui/screens/sync_view.dart` | Modified | Dynamic QR + pairing code |
| `lib/infrastructure/sync/sync_service.dart` | Modified | Add performSync flow |
| `lib/infrastructure/sync/sync_repository_impl.dart` | Modified | Include tagsColors in sync |
| `test/infrastructure/sync/sync_integration_test.dart` | New | E2E sync test |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Protected entries undecryptable cross-device | High | Show placeholder, document limitation |
| SyncCoordinator logic errors (wrong conflict detection) | Medium | Unit test conflict scenarios |
| Time to wire everything | Low | Most pieces exist, just need connection |

## Rollback Plan

- Revert changes to sync_providers.dart (restore null provider)
- Remove sync_coordinator.dart
- Integration test is non-destructive

## Dependencies

- Existing phase3-sync infrastructure (all already in pubspec.yaml)

## Success Criteria

- [ ] Two devices on same WiFi can pair via QR + 6-digit code
- [ ] Modified entries sync bidirectionally (delta)
- [ ] Conflicts detected when both devices modify same entry
- [ ] ConflictView lets user pick local/remote/both
- [ ] Protected entries sync but show placeholder if DEK mismatch
- [ ] Integration test validates full sync flow
