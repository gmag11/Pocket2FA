# Design

## Context

See `proposal.md` - Why. Current state:

- `SyncService` is a stateless singleton with three public entry points:
  `syncIfNeeded`, `forceSync` and `uploadPendingAccounts`.
- `syncIfNeeded` reads two Hive keys per server (`last_sync_<id>` and
  `last_sync_forced_<id>`) and applies a 15-minute throttle before delegating.
- `forceSync` runs pending deletes, creates and updates, then fetches groups and
  accounts, filters/merges local state, downloads icons and persists the server
  snapshot plus sync timestamps.
- The pending helpers are private but are reached through `forceSync` and
  `uploadPendingAccounts`, so tests can exercise them without production seams.
- `ApiService` is a singleton. Its `setServer` recreates `Dio` only when the
  server identity changes; `ApiTestHarness` can attach a mock adapter when the
  same server is configured first.
- `FakeSettingsStorage` already provides an in-memory Hive box and a locked
  variant. `ApiTestHarness`, the `ServerConnection` fixture and
  `resetLogService` already exist.
- The coverage baseline is 19.15%; `sync_service.dart` has 343 executable lines
  at 0%.

## Goals / Non-Goals

**Goals:**

- Cover the observable contracts of all three public entry points: throttle
  decisions, pending-mutation effects, fetched-data filtering/merging,
  persistence and result maps.
- Exercise failure behavior: network failures, malformed persisted data,
  locked storage, API errors and fetch failures.
- Keep tests deterministic, with no platform channels, real sockets or leaked
  timers.
- Reuse existing fixtures and require no production refactor.

**Non-Goals:**

- Covering successful icon downloads or the `icon_cache_service.dart` module.
  Those need a path-provider fake and a controllable icon transport and belong
  in a dedicated stage.
- Refactoring `SyncService` for constructor injection. The public entry points
  already expose enough behavior through the API and storage singletons.
- Covering screens or the UI sync manager in this stage.
- Chasing defensive `catch` branches that cannot be reached through public
  behavior.

## Decisions

### One focused service test file

Add `test/unit/services/sync_service_test.dart`. Keeping the whole service in
one file makes the fetch/pending interactions visible and avoids a shared helper
sprawling across files. The file is grouped by entry point: `syncIfNeeded`,
`forceSync` fetch/persistence, pending mutations and failure handling.

### Drive the real singletons through existing fixtures

Each test creates a `ServerConnection` fixture and a `FakeSettingsStorage` seeded
with the `servers` list and last-sync keys it needs. Configure
`ApiService.instance` with the same server *before* creating
`ApiTestHarness(api.dio)`, so the internal `setServer` calls in `forceSync` are
no-ops and keep the mock adapter attached. `setUp`/`tearDown` close the API and
reset `LogService`.

Alternatives considered: adding injection seams to `SyncService` or an HTTP
client parameter. Both would change production code for testability and are
unnecessary while the singleton harness already works for the API service.

### Isolate pending mutations from the final fetch

`forceSync` persists the fetched account list after pending mutations. A
successful fetch would therefore overwrite the upload/update/delete result being
asserted. For pending-mutation tests, make the groups or accounts fetch fail
(HTTP 500) so `forceSync` returns its network-failure map after the mutation has
already persisted. Happy-path fetch tests seed no pending mutations.

`uploadPendingAccounts` is tested directly for the create path because it never
fetches and its return value is the upload count. Delete and update are exercised
through `forceSync` because they have no public wrapper.

### Assert storage and requests, not private state

- `syncIfNeeded`: assert the result map, whether a request was made, and the
  persisted forced flag.
- `forceSync`: assert the returned summary, the recorded GET/DELETE/POST/PUT
  request paths, query parameters and bodies, and the `servers`/last-sync values
  written through `FakeSettingsStorage.values`.
- `uploadPendingAccounts`: assert the returned count and the persisted account
  id/group/synchronized state.

Expected high-value cases:

- Throttle skip, forced override, old/corrupt/missing timestamps and locked
  storage.
- Groups/accounts fetch success, non-list responses and thrown errors;
  `withSecret=true`; network failure without persistence.
- Group-name mapping from fetched groups and from `server.groups` fallback.
- Pending-delete filtering, local-only tombstone purge, and keeping local-only
  pending creates after a fetch.
- Create with id, missing id, API failure, group retention and missing server.
- Update with group retention, local-icon retention, missing id and API failure.
- No-icon success summaries and icon cancellation without invoking the icon
  service.

### Cancel icons through an interceptor, not a pre-cancelled token

`forceSync` passes the same `CancelToken` to the accounts GET and the icon loop.
Pre-cancelling it would fail the GET before the icon loop is reached. For the
cancellation test, add an `InterceptorsWrapper` that cancels the token in
`onResponse` after the accounts response, then assert the icon loop breaks and
the summary reports zero downloads/failures. This avoids path-provider and real
icon transport.

### Raise the baseline only after measurement

Run `flutter test --coverage` and `dart run tool/check_coverage.dart`, then set
`.coverage-baseline` to the measured overall value. The expected gain is roughly
4-5 points (around 24-26% overall), but the measured value wins. Do not raise the
baseline in anticipation.

## Risks / Trade-offs

- **Singleton state leaks between tests** → close `ApiService` and reset
  `LogService` in `setUp`/`tearDown`; create a fresh `FakeSettingsStorage` per
  test.
- **`setServer` recreates `Dio` and drops the mock adapter** → configure the
  same server before installing the harness and use a fixture with the same
  id/url/apiKey/allowSelfSigned values.
- **The final fetch overwrites pending-mutation state** → force the fetch to
  fail in those tests and assert the storage written by the pending step.
- **Wall-clock throttle tests are flaky near boundaries** → seed timestamps far
  inside or outside the 15-minute window; never assert exact remaining time.
- **Icon success paths need platform plugins** → test only no-icon and cancelled
  paths here; defer successful downloads to the icon-cache stage.
- **Malformed storage tests may throw in unexpected places** → assert only that
  sync returns a result and does not persist last-sync keys, not the exact
  internal catch path.
- **Coverage denominator is already complete** → adding a test file does not
  require changing `test/coverage/import_all_test.dart`; `sync_service.dart` is
  already imported.

## Migration Plan

Not applicable: test-only change, no data or deployment migration. Rollback is
deleting the new test and restoring the previous baseline.

## Open Questions

None that affect scope. The exact achievable percentage will be known only
after the tests run; the baseline task uses the measured value.
