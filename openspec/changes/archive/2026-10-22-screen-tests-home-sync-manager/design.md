# Design

## Context

See `proposal.md`. `HomeSyncManager` calls the global `SyncService.instance`
and `ApiService.instance`, so tests must configure those before triggering a
sync. `FakeSettingsStorage` provides the encrypted-box replacement.

## Decisions

- Build a real `HomeServerManager` from seeded fake storage and a selected
  server, then wrap it with `HomeSyncManager`.
- Use `ApiTestHarness` for account/group/OTP endpoints and fake storage for
  persistence; assert the refreshed server lists and reachability calls.
- Use `fake_async` for retry timers/backoff; cancel or dispose the manager's
  timers by replacing the test zone at the end.
- Cover `onRefreshFromPull` suppression by asserting it is true during the
  callback's pending future and false afterward.
- Test upload failure/success summaries without real sockets.

## Risks

- **Global services** → reset `ApiService` and logs in setup/teardown.
- **Timers** → fake async and bounded retry assertions.
- **Storage** → seed a server with a pending local account.
- **Network** → mock adapter only.
