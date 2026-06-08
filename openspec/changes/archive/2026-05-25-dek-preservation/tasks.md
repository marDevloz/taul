# Tasks: DEK Preservation During Recovery

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 550–700 |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | 6 chained PRs (feature-branch-chain) |
| Delivery strategy | auto-chain |

Decision needed before apply: No
Chained PRs recommended: Yes
Chain strategy: feature-branch-chain
400-line budget risk: High

| Unit | Goal | PR | Base |
|------|------|----|------|
| 1 | Schema v4 + store read/write/consume | PR 1 | `dek-preservation` tracker |
| 2 | `unwrapDekFromBackupCode` + `generateBackupCodesWithDekWraps` | PR 2 | PR 1 branch |
| 3 | Setup: wrap DEK per code in controller + dialog | PR 3 | PR 2 branch |
| 4 | Recovery: unwrap DEK + atomic consume | PR 4 | PR 3 branch |
| 5 | Regen: `requireMasterKey` + settings MP prompt | PR 5 | PR 4 branch |
| 6 | Integration + e2e tests | PR 6 | PR 5 branch |

## Phase 1: Schema + Store (PR 1)

- [x] 1.1 Add `backupCodeData` TEXT col to `MasterPasswordConfigTable`
- [x] 1.2 Bump schemaVersion 4, add `from < 4` migration in `AppDatabase`
- [x] 1.3 `BackupCodeEntry` model with `fromJson`/`toJson` in store
- [x] 1.4 `readBackupCodeData()` → `List<BackupCodeEntry>?` in store
- [x] 1.5 `consumeBackupCodeAtIndexAndData(int)` — atomic dual-array remove
- [x] 1.6 Modify `saveFull()`: optional `backupCodeDataJson` param
- [x] 1.7 Tests: JSON round-trip, consume atomicity, v3→v4 migration

## Phase 2: Crypto + Domain (PR 2)

- [x] 2.1 `unwrapDekFromBackupCode(code, hashes, data)` in `RecoveryService`
- [x] 2.2 `generateBackupCodesWithDekWraps(dek, count)` helper in `EntryAuthService`
- [x] 2.3 Tests: unwrap valid/tampered code, real-crypto round-trip

## Phase 3: Setup Flow (PR 3)

- [x] 3.1 Controller: iterate codes → backup-KEK per code → AES-256-GCM wrap DEK → build JSON
- [x] 3.2 Round-trip verify first entry before returning
- [x] 3.3 Dialog: pass `backupCodeDataJson` to `saveFull`

## Phase 4: Recovery Flow (PR 4)

- [x] 4.1 Read `backup_code_data` before consuming code
- [x] 4.2 Call `consumeBackupCodeAtIndexAndData` after verify
- [x] 4.3 Derive backup-KEK → unwrap DEK → re-wrap with new KEK
- [x] 4.4 New codes → wrap DEK → `saveFull` with new data
- [x] 4.5 NULL `backup_code_data` → generate new DEK (fallback)

## Phase 5: Code Regen (PR 5)

- [x] 5.1 `requireMasterKey(context)` → `Uint8List` in controller
- [x] 5.2 Settings: trigger `requireMasterKey` before regen
- [x] 5.3 New codes → wrap DEK → atomic save hashes + data

## Phase 6: Integration Tests (PR 6)

- [x] 6.1 Setup → recovery preserves DEK (old entries decryptable)
- [x] 6.2 v3 compat: no column → new DEK generated
- [x] 6.3 Settings regen shows MP prompt (fake auth + store) — pre-existing (PR 5)
- [x] 6.4 Recovery dialog unwraps DEK with fake `backup_code_data` — pre-existing (PR 4)

## Implementation Order

PR 1 → PR 2 → PR 3 → PR 4 → PR 5 → PR 6. Each targets the previous PR branch. Only the `dek-preservation` tracker merges to main.
