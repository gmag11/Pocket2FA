# Proposal

## Why

`HomeSyncManager` is 173 executable lines at 0%. Its network/upload paths depend
on the global `SyncService`, but the state and early-return paths are
deterministic and important: sync indicators, pending-upload detection, retry
pausing and the no-server/no-storage guards.

## What Changes

- Add tests for the deterministic `HomeSyncManager` API:
  - syncing and suppression flags plus notifications;
  - pending-upload detection for owned/local/deleted/borrowed accounts;
  - retry pausing/resuming and `ensurePendingUploads` early returns;
  - `forceSyncCurrentServer`/refresh guards with no server or storage.
- Raise `.coverage-baseline` to the measured overall value after the stage.

No production code, dependencies or public behavior changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This is test-only work; the change declares `skip_specs: true`.

## Impact

- New test `test/unit/screens/home_sync_manager_test.dart`.
- Uses a mocked `HomeServerManager`; no new dependencies.
- `.coverage-baseline` rises from 63.11 to the measured value (expected around
  64-65%, not guaranteed).
- No `lib/` changes, so the release APK and Android install are unaffected.
- Successful `SyncService` uploads/fetches remain for a dedicated service-harness
  stage.
