# Design

## Context

See `proposal.md` - Why. `HomeManageMode` wraps a `HomeServerManager` and
handles selection/deletion. Deletion shows a confirmation dialog, updates the
in-memory server, persists it, optionally calls `ApiService.deleteAccounts` and
shows a SnackBar. A `MockHomeServerManager` lets tests control the current items,
servers and selected id without real storage.

## Goals / Non-Goals

**Goals:**

- Cover selection rules and the deletion decision branches.
- Cover local-only accounts, missing server, API-not-ready and API success.
- Cover dialog cancel/confirm and SnackBars.

**Non-Goals:**

- Testing `HomeServerManager` persistence (next stage).
- Rendering the full home screen.
- Real network calls.

## Decisions

### Mock the manager

```dart
class MockHomeServerManager extends Mock implements HomeServerManager {}
```

Stub `currentItems`, `servers`, `selectedServerId`, `persistServersToStorage`,
`updateServersInMemory` and `updateServerReachability`. Use `verify` for the
persistence and reachability calls.

### Selection tests are pure

`toggleManageMode` and `toggleAccountSelection` do not need a widget binding.
Use `test()` and assert the mode/selection sets and notifications. A borrowed
account is never added to the selection.

### Deletion through a Builder

Pump a `Scaffold` with a `Builder` whose button calls
`mode.deleteSelectedAccounts(context)` and stores the returned bool. Then:

- no selection -> returns false without a dialog;
- cancel -> returns false and the manager is unchanged;
- confirm -> assert the updated server passed to `updateServersInMemory`, the
  persistence call and the success SnackBar.

Keep the callback's `BuildContext` from the `Builder`, not from the test root.

### Local-only accounts

Select an account with `id <= 0`; after confirmation it is removed from the
updated server without `ApiService.deleteAccounts`, and the result is true.
`ApiService` is closed in this test so any accidental call would be obvious.

### Missing server and API-not-ready

- Set `selectedServerId` to an id not present in `servers`; assert `false`,
  `updateServerReachability(false)` and `noServerSelected`.
- For a positive id with `ApiService.instance.close()`, assert `true`, the
  account marked deleted/unsynchronized, persistence, and
  `updateServerReachability(false)`.

### API success

Configure the shared `ApiService` and `ApiTestHarness` with a DELETE response
for `twofaccounts?ids=<id>`; after confirmation assert the deleted account is
removed from the final in-memory server and reachability is restored. Close the
API in teardown.

## Risks / Trade-offs

- **Global ApiService** → close/set it in setup and teardown.
- **Dialog context** → always call from a real `Builder` button.
- **SnackBar timers** → pump past two seconds where a SnackBar is asserted.
- **Mock getters** → stub every getter used by the branch under test.
- **Local-only deletion** → ensure no DELETE request is recorded.
- **Notification counts** → assert the meaningful state, not exact counts.

## Migration Plan

Not applicable: test-only change. Rollback is deleting the new test and
restoring the previous baseline.

## Open Questions

None that affect scope. Exact coverage will be measured after the test runs.
