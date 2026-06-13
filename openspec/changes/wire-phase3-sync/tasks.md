# Tasks: Wire Phase 3 Sync

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~285 |
| 400-line budget risk | Low |
| Chained PRs recommended | Yes (user preference: force-chained) |
| Chain strategy | stacked-to-main |
| Suggested split | PR 1 → PR 2 |

### Work Units

| Unit | Goal | Likely PR | Lines | Notes |
|------|------|-----------|-------|-------|
| 1 | SyncCoordinator + wire SyncService + providers | PR 1 | ~120 | Core orchestration. Independent, no UI changes. |
| 2 | QR pairing + SyncView + crypto policy + tests | PR 2 | ~165 | UI changes + integration test. Depends on PR 1 for full flow. |

---

## PR #1: SyncCoordinator + Service Wiring (~120 lines)

- [ ] 1.1 Create `lib/infrastructure/sync/sync_coordinator.dart` — class that implements `handleSyncRequest(SyncRequest)`: loads local delta via ISyncRepository.getModifiedEntries, calls ConflictResolver.detectConflicts, stores conflicts via ConflictDao.insert, upserts non-conflicting entries via ISyncRepository.upsertEntries, sets lastSyncAt via ISyncRepository.setLastSyncAt, returns SyncResponse with local delta + conflictsCount.
- [ ] 1.2 Create `lib/infrastructure/sync/sync_coordinator_test.dart` — unit test SyncCoordinator with mock ISyncRepository + ConflictDao: test conflict detection, test no-conflict upsert, test delta return.
- [ ] 1.3 Modify `lib/ui/providers/sync_providers.dart` — replace `syncServiceProvider` (currently returns null) with real SyncService wired to CertificateManager, SyncServer, SyncClient, SyncCoordinator, deviceIdProvider, and databaseProvider. Add intermediate providers: `certificateManagerProvider`, `syncCoordinatorProvider`, `syncServerProvider`.
- [ ] 1.4 Modify `lib/infrastructure/sync/sync_service.dart` — ensure `performSync` is callable from providers. The method already exists but verify the signature matches what the coordinator needs.

**Files created:** sync_coordinator.dart, sync_coordinator_test.dart
**Files modified:** sync_providers.dart, sync_service.dart (minor)

---

## PR #2: QR Pairing + SyncView + Crypto Policy + Integration Test (~165 lines)

- [ ] 2.1 Modify `lib/ui/screens/sync_view.dart` — replace hardcoded `QrImageView(data: 'https://sync.taul.local')` with real data from PairingService.getLocalIpAddress() + server.port. Display 6-digit pairing code from PairingService.generateCode() below QR. Show "Escaneá este QR desde el otro dispositivo" help text.
- [ ] 2.2 Modify `lib/infrastructure/sync/pairing_service.dart` — verify `generateQrData(ip, port)` returns correct URL format. Ensure `getLocalIpAddress` works cross-platform.
- [ ] 2.3 Add crypto policy for protected entries — in SyncCoordinator, ensure encryptedSecret/cipherNonce/cipherTag are transmitted as opaque blobs (already in Entry model, verify serialization). Add comment documenting DEK isolation policy.
- [ ] 2.4 Modify `lib/infrastructure/sync/sync_repository_impl.dart` — verify `getModifiedEntries` and `upsertEntries` handle `tagsColors` field. The Entry model has `tagsColors` but the DAO may not persist it. Audit `entry_dao.dart:_toCompanion` and the database schema.
- [ ] 2.5 Create `test/infrastructure/sync/sync_integration_test.dart` — E2E test: two in-memory databases, start SyncServer on one, SyncClient connects, entries sync bidirectionally, conflicts detected, resolved.
- [ ] 2.6 Update `test/ui/screens/sync_view_test.dart` — verify QR shows with real data mock, pairing code displayed.

**Files modified:** sync_view.dart, pairing_service.dart, sync_repository_impl.dart (minor), entry_dao.dart (if tagsColors missing)
**Files created:** sync_integration_test.dart
**Tests modified:** sync_view_test.dart

---

## Task Dependency Graph

```
PR #1 (Coordinator + Wiring)
  ├─ 1.1: SyncCoordinator class (no deps)
  ├─ 1.2: Unit tests for coordinator (depends on 1.1)
  ├─ 1.3: Wire providers (depends on 1.1, uses existing SyncServer/SyncClient)
  └─ 1.4: Minor sync_service.dart tweaks (low dep)

PR #2 (UI + Crypto + Tests) — depends on PR #1's SyncCoordinator
  ├─ 2.1: QR in SyncView (uses pairing service)
  ├─ 2.2: Pairing service polish (no deps)
  ├─ 2.3: Crypto policy docs (verification task)
  ├─ 2.4: tagsColors audit (verification task)
  ├─ 2.5: Integration test (depends on all pieces)
  └─ 2.6: SyncView test update (depends on 2.1)
```
