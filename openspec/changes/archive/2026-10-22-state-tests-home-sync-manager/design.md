# Design

## Context

See `proposal.md` - Why. `HomeSyncManager` reads `HomeServerManager.servers`,
`selectedServerId` and `settings`, and calls `SyncService.instance` only after
the early guards pass. A mock server manager lets tests cover the state and
guard branches without a network or upload.

## Goals / Non-Goals

**Goals:**

- Cover syncing/suppression flags and notifications.
- Cover pending-upload detection and retry pause/resume.
- Cover no-pending, no-server and no-storage early returns.
- Keep `SyncService` out of the tests.

**Non-Goals:**

- Real force-sync or pending uploads.
- Timers beyond scheduling/no-pending cancellation.
- The full home screen.

## Decisions

### Mock the server manager

Create `MockHomeServerManager extends Mock implements HomeServerManager`, stub
`servers`, `selectedServerId` and `settings`, and no-op `loadServers`,
`updateServerReachability` where needed.

### Pending detection

Build `ServerConnection` fixtures with accounts:

- local pending (`id < 0`, unsynchronized, not deleted, not borrowed) -> true;
- deleted/borrowed/synchronized -> ignored;
- no selected server / empty servers -> false.

`_currentServer` falls back to the first server when the selected id is missing.

### Flags and retries

`setSyncing` changes only when the value differs and notifies. The suppression
flag is a simple setter. `setRetryPaused` cancels on pause and schedules a retry
on resume only when pending uploads exist. `ensurePendingUploads` stops when
nothing is pending and returns immediately when paused.

### Guards

`forceSyncCurrentServer` returns without calling `SyncService` when the
selection, storage or server list is missing. `onRefreshFromPull` toggles the
full-screen suppression around that call and restores it afterward. Use a
`SettingsService` with no storage for the storage-null guard.

### No timer assertions

The retry timer is an implementation detail; assert the state and avoid ending
with a pending widget timer. These are plain `test()` cases.

## Risks / Trade-offs

- **Global SyncService** → never let a test reach the sync call.
- **Mock getters** → stub every getter used by the branch.
- **SettingsService with no storage** → set mock shared preferences first.
- **Timer scheduling** → keep retry tests in plain `test()` and do not assert
  delay internals.
- **Selected-server fallback** → intentionally cover the `orElse` path.

## Migration Plan

Not applicable: test-only change. Rollback is deleting the new test and
restoring the previous baseline.

## Open Questions

None that affect scope. Exact coverage will be measured after the test runs.
