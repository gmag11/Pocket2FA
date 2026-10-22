# Design

## Context

See `proposal.md` - Why. `HomePage` owns four managers, a header animation,
search state, auto-sync timer and desktop-drop/intake state. All child widgets
have their own tests. This stage starts with an empty fake store so the server
manager has no servers and no network/sync work.

## Goals / Non-Goals

**Goals:**

- Pump the real `HomePage` and cover its startup/build path.
- Cover empty-server/empty-account states and main controls.
- Cover settings/accounts navigation if the controls are reachable.
- Dispose timers/controllers cleanly.

**Non-Goals:**

- Live sync, incoming share/drop or manage-mode interactions.
- Real storage/Hive or network.
- Every branch of the 616-line file.

## Decisions

### Empty fake storage

`FakeSettingsStorage` with no `servers` key gives an empty home. Mock the
path-provider channel for desktop staging to a temporary directory. Build
`SettingsService(storage: fake)`, reload, then `pumpApp(HomePage(settings))`.

### Pumping

Avoid `pumpAndSettle` around a page with auto-sync/animations unless it settles
immediately. Pump a few short frames after startup, assert the empty state, then
replace the tree with `SizedBox` and pump to dispose timers.

### Controls

Locate the search field, the `BottomBar` no-server text and the add FAB. For
navigation, use icon/tooltip finders only where the build clearly exposes them;
otherwise leave deeper navigation to the next stage.

### Coverage pin

The baseline is already pinned at 70.0; leave it there unless the measured value
is higher and the policy still calls for raising.

## Risks / Trade-offs

- **Auto-sync/timers** → empty servers means no auto-sync; always dispose.
- **Desktop drop** → mock path provider and do not simulate drops.
- **Incoming channel** → only registered on Android; Linux skips it.
- **Async startup** → pump after `loadServers`; assert empty state.
- **Large build** → one focused smoke test rather than brittle pixel checks.

## Migration Plan

Not applicable: test-only change. Rollback is deleting the new test and
restoring the previous baseline.

## Open Questions

None that affect scope. Exact coverage will be measured after the test runs.
