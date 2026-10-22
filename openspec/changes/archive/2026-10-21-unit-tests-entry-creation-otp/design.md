# Design

## Context

See `proposal.md` - Why. Current state:

- `EntryCreationService` has three public entry points. `parseOtpAuthUrl` and
  `buildManualEntry` are pure apart from `LogService`; `createEntryOnServer`
  calls `ApiService.instance` directly.
- `AccountTileOtpService` mixes synchronous local OTP generation, timers and
  `ApiService.instance` calls. It has no injection seam for the API or clock.
- The test suite already has `ApiTestHarness` (Dio mock adapter that records
  requests), `withFixedTime`, `FakeSettingsStorage`, `pumpApp` and a
  `resetLogService` helper.
- `ApiService` is a singleton with a private constructor, but tests can replace
  its transport through `setServer` plus `ApiTestHarness(api.dio)`. That is how
  the API service tests already exercise it.
- The coverage gate counts every non-generated `lib/` file and is currently at
  15.62% overall / 44.92% core.

## Goals / Non-Goals

**Goals:**

- Cover the observable contracts of both modules: parsed entry fields, payload
  shape, merge behavior, OTP routing, offline states and timer lifecycle.
- Reuse the existing fixtures instead of adding production seams or new
  dependencies.
- Keep tests deterministic and free of platform channels, real sockets and
  leaked timers.

**Non-Goals:**

- Refactoring `EntryCreationService` or `AccountTileOtpService` for dependency
  injection. That would be a production change and is not needed to test the
  public behavior through the singleton harness.
- Covering `sync_service.dart`, screens or unrelated widgets in this stage.
- Fixing the existing debug-only payload log in `createEntryOnServer`, or
  asserting its redaction here; changing it is a production decision.
- Chasing 100% line coverage of unreachable defensive `catch` blocks.

## Decisions

### Split tests by binding requirements

- `test/unit/services/entry_creation_service_test.dart`: parsing, manual entry
  building, Base32 validation and server creation. No Flutter binding, so
  `ApiTestHarness` can drive Dio normally.
- `test/unit/widgets/account_tile_otp_service_test.dart`: local generation,
  server routing, retry/offline states and HOTP. `fake_async` for timer tests.
- `test/widget/entry_creation_snackbar_test.dart`: one widget test for the
  invalid-QR SnackBar. It needs a mounted `BuildContext` and localized text, and
  the Flutter test binding replaces the real HTTP client. Keeping it separate
  preserves the real-socket behaviour used by `api_service_test.dart`.

Extend `shared_account_otp_test.dart` only if a routing assertion belongs with
its existing scenarios; otherwise keep the new coverage in the focused files so
test failures point at one module.

### Drive the API singleton through `ApiTestHarness`

`createEntryOnServer` and `AccountTileOtpService` call `ApiService.instance`, so
the test configures that singleton with a fixture `ServerConnection` and a
`DioAdapter`, then asserts the recorded request. This needs no production
refactor and exercises the real serialization/merge code.

`setUp` closes `ApiService.instance` and resets `LogService`; `tearDown` does
the same. Each test that creates a service registers `svc.dispose` via
`addTearDown` so a failing assertion cannot leak a timer into the next test.

### Use a fixed clock for code values, timers for scheduling

`OtpService` reads `clock.now()`, so local TOTP/Steam assertions use
`withFixedTime` and the existing RFC 6238 vectors. `AccountTileOtpService`
schedules with `DateTime.now()` and `Timer`; scheduling tests use `fake_async`
and assert observable effects (`refreshUi` calls, code changes, offline state)
rather than private timer fields.

For network paths, the mocked adapter resolves through microtasks, so
`fakeAsync.flushMicrotasks()` is enough to complete the request. If a specific
Dio adapter path does not settle under `fake_async`, that test drops back to
real async and disposes the service immediately; timer-expiry behaviour remains
covered by the no-network paths.

### Assert public results, not implementation details

- Parsing tests assert the returned `AccountEntry` fields, or `null` for invalid
  input. They do not call private helpers.
- `createEntryOnServer` tests assert the recorded `RequestOptions.data`, the
  merge result and the local-entry fallback on transport errors.
- OTP tests assert `currentCode`, `nextCode`, `hotpCode`, `hotpCounter`,
  `refreshUi` counts and animation callbacks.

Expected high-value cases:

- TOTP/HOTP defaults, issuer/label/group rules, colon replacement, Base32
  rejection and percent-decoded labels.
- HOTP counter fallback to period and then 0; TOTP period fallback to 30.
- Group name populated from `groups` when the response has only `group_id`.
- Local TOTP and Steam codes; borrowed/empty-seed server routing; id <= 0
  offline without a request; empty password, API failure and retry.
- Server refresh scheduling from `generated_at` (seconds, milliseconds,
  string, missing), HOTP int/string/missing counter and 30-second expiry.

### Raise the baseline only after measurement

Run `flutter test --coverage` and `dart run tool/check_coverage.dart`. Then set
`.coverage-baseline` to the measured overall value. The expected gain is about
1.5-3 points (roughly 18-19% overall), but the measured value wins. Do not raise
the baseline in anticipation.

## Risks / Trade-offs

- **Singleton state leaks between tests** → close `ApiService` and reset
  `LogService` in `setUp`/`tearDown`; always dispose the OTP service.
- **Pending timers fail or hang the test run** → use `fake_async`, dispose
  before the test ends, and avoid `elapse` loops that re-arm the 30-second
  retry indefinitely.
- **Timer tests become time-sensitive** → assert callbacks and states, not exact
  wall-clock delays; fix `generated_at` so the server boundary is deterministic.
- **The debug payload log can contain the secret** → do not enable log capture
  for `createEntryOnServer` in this stage. Redacting that log is a separate
  production change.
- **The widget test needs the binding** → keep it in its own file and do not use
  real sockets there.
- **Coverage denominator is already complete** → adding test files does not
  require changing `test/coverage/import_all_test.dart`; both targets are
  already imported.

## Migration Plan

Not applicable: test-only change, no data or deployment migration. Rollback is
deleting the new tests and restoring the previous baseline.

## Open Questions

None that affect scope. The exact achievable percentage will be known only
after the tests run; the baseline task uses the measured value.
