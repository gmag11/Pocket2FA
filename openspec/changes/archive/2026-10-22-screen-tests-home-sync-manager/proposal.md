# Proposal

## Why

The first home-sync stage covered state and early guards; 112 executable lines
remain in the actual force-sync, pending-upload and retry paths. These are the
network-adjacent behaviors that the home page delegates to this manager.

## What Changes

- Add tests for the remaining `HomeSyncManager` paths:
  - force sync success, skipped and network-failure summaries;
  - pending uploads, retry scheduling and backoff reset;
  - refresh suppression around `onRefreshFromPull`;
  - API/upload failure reachability updates.
- Raise `.coverage-baseline` to the measured value (pinned at 70 if above).

No production code, dependencies or public behavior changes.

## Impact

- Extends `test/unit/screens/home_sync_manager_test.dart`.
- Uses real `HomeServerManager` with `FakeSettingsStorage` and `ApiTestHarness`
  where the sync service needs a server.
- No `lib/` changes; release APK and device are unaffected.
