# Design

## Context

See `proposal.md` for motivation. The constraints that shape this design:

- `lib/` is ~12.8k non-generated lines: `screens` 6.3k, `services` 4.0k, `widgets` 1.9k,
  `models` 0.5k, plus generated `l10n` 3.4k and `main.dart`.
- Services depend on singletons (`ApiService.instance`, `SyncService.instance`,
  `LogService.instance`) and instantiate platform plugins internally (`Hive`, `flutter_secure_storage`,
  `local_auth`, `shared_preferences`, `path_provider`, `window_manager`).
- `SettingsStorage` is a concrete class, but its methods are overridable and `SyncService` accepts a
  `SettingsStorage` parameter, so a subclass fake is viable without production changes.
- `OtpService` and `LogService` call `DateTime.now()` directly.
- Coverage of all `lib/` at 70% is unreachable with unit tests alone; unit tests can reach roughly
  35% (the `models` + `services` core). Widget tests are required for the rest.
- Work continues on `tests/deferred-unit-tests`, which already carries history for two deferred
  tests that can seed the harness.

## Goals / Non-Goals

**Goals:**

- A hermetic unit-test harness that runs with `flutter test` and no device.
- Deterministic time for the services that need it.
- Coverage numbers that ignore generated code and separate overall vs. unit-testable progress.
- A ratchet that lets coverage grow without allowing it to fall.
- A layout that accepts widget tests later without restructuring.

**Non-Goals:**

- Reaching 70% in this change. This change delivers infrastructure plus a seed suite; the bulk of
  unit tests and all widget tests come in follow-up changes.
- Refactoring singletons into constructor-injected services. Only the seams needed for tests are
  touched.
- Testing native platform behavior (Hive encryption, secure storage, biometrics) in a unit suite.
- Replacing the existing build workflows or adding test reporting services.

## Decisions

### D1: Use `package:clock` for injectable time

`OtpService` and `LogService` call `clock.now()` instead of `DateTime.now()`. Production code keeps
the default system clock, so behavior is unchanged. Tests wrap a call in
`withClock(Clock.fixed(DateTime.utc(...)), () async { ... })`, which overrides the global clock for
the duration of the zone.

Alternatives:

- Passing a `DateTime Function()` parameter: explicit, but it changes signatures and forces every
  caller to thread the clock through.
- Keeping `timeOffsetSeconds` only: works for "now +/- N", but cannot pin a published RFC 6238
  timestamp, so boundary tests stay nondeterministic.

`clock` is a small pure-Dart runtime dependency with no plugin or platform code.

### D2: `mocktail` plus hand-written fakes

Use `mocktail` for collaborators that are awkward to subclass (for example a `Dio` adapter) and
hand-written fakes where a subclass is clearer:

- `FakeSettingsStorage extends SettingsStorage`, overriding `box`, `isUnlocked`, `hasPin`,
  `pinLength`, `supportsBiometrics`, and the read/write methods the test needs. No plugin call is
  reached.
- `FakeDio`/`FakeHttpClientAdapter` for API response mapping, only when an API-level test needs one.
- `FakeSettingsService`: `SettingsService` already accepts an optional storage and falls back to
  `SharedPreferences`, so widget tests use `SharedPreferences.setMockInitialValues({})` or a fake
  storage. No production seam is required.

`mocktail` is preferred over `mockito` because the project has no `build_runner`; `mocktail`
requires no code generation. `fake_async` covers timer-driven behavior (`AccountTileOtpService`)
and `http_mock_adapter` is available if Dio-level tests need request matching.

### D3: Two-layer test layout, unit now, widget prepared

```
test/
  unit/models/       pure model parsing, copyWith, merge
  unit/services/     OTP, log, entry parsing, sync merge, storage classification
  widget/            screens and widgets (phase 2)
  helpers/           fakes, pump helper, clock helper, log reset
  fixtures/          JSON payloads from the 2FAuth API
```

Unit tests must not touch the widget layer. Widget tests will use a `pumpApp()` helper that wraps a
widget in `MaterialApp` with the app's localization delegates and a test `SettingsService`. Creating
that helper now is cheap and prevents every widget test from repeating setup later.

### D4: Custom Dart coverage script

`tool/check_coverage.dart` parses `coverage/lcov.info` and:

1. drops every record whose path contains `lib/l10n/`,
2. computes overall coverage from the remaining records,
3. computes the `lib/models` + `lib/services` subset,
4. prints both, plus the baseline and the 70% target,
5. exits non-zero when overall coverage is below the baseline.

Alternatives:

- `very_good_coverage` / Node-based `lcov` tooling: adds a Node or Dart package dependency and a
  second toolchain for a task that is a few dozen lines of line counting.
- A shell/`awk` script: workable but harder to keep readable and test on Windows.

The script is self-contained, runs with the installed Dart SDK, and works identically on all CI
platforms. It is itself unit-testable when it grows.

### D5: Ratchet baseline in a file

`.coverage-baseline` stores a single floating-point number (the minimum accepted overall coverage).
CI compares and fails below it. Raising the baseline is an explicit, reviewable change in the same
commit that raises coverage. When overall coverage reaches 70%, the file is set to `70.0` and the
check effectively pins that floor.

Alternatives:

- Comparing against the base branch on every run: more accurate for long-lived branches, but it
  requires fetching and measuring the base branch, multiplies CI time, and makes failures harder to
  reproduce locally.
- No baseline until 70%: fails the purpose of preventing regressions during the climb.

### D6: Hermetic unit tests

Unit tests never initialize Hive or call a plugin. `TestWidgetsFlutterBinding.ensureInitialized()` is
called only where framework services are needed (for example `SchedulerBinding` in `LogService`);
that binding is not a platform channel. Each test resets singleton state it touches
(`LogService.instance.clear()`, `SettingsService` instance replacement) in `setUp`/`tearDown`.

### D7: CI workflow mirrors the existing setup

`.github/workflows/test.yml` runs on `push` and `pull_request`, uses `subosito/flutter-action` with
Flutter `3.47.7` (matching the other workflows and `.flutter-version`), caches pub, then runs:

1. `flutter pub get`
2. `flutter analyze`
3. `flutter test --coverage`
4. `dart run tool/check_coverage.dart`

The build workflows are untouched.

## Risks / Trade-offs

- **Unit-only coverage plateaus around 35%, far from 70%** -> The ratchet protects the gain and the
  spec reports both metrics; widget tests in phase 2 close the gap. Do not lower the target.
- **`withClock` is zone-scoped and easy to leak** -> Helpers wrap the whole async body; tests that
  need a fixed clock use the helper rather than setting the clock ad hoc.
- **Singleton state leaks between tests** -> Reset helpers and fresh instances in `setUp`; prefer
  constructing `SettingsService` per test over reusing `SettingsService.instance`.
- **Faking `SettingsStorage` by subclassing couples tests to its surface** -> Acceptable for phase 1;
  if the surface grows unwieldy, extract a narrow read/write interface in a later change.
- **Coverage flakiness from platform-specific files** -> Exclude generated l10n only; do not
  exclude real code. Platform-bound services are covered through their pure branches and fakes.
- **Baseline gets bumped without real coverage** -> The script prints measured vs. baseline; the
  baseline value is visible in the diff and reviewed like any other number.
- **CI runs tests twice if later added to build workflows** -> Keep the test job isolated; builds
  stay unchanged.

## Migration Plan

1. Add dependencies and run `flutter pub get`.
2. Replace direct `DateTime.now()` with `clock.now()`; behavior unchanged under the default clock.
3. Add `test/` layout, helpers, and fixtures; recover the two deferred tests from history and make
   them pass.
4. Add `tool/check_coverage.dart` and `.coverage-baseline` initialized to the measured value.
5. Add the CI workflow and confirm the gate passes and fails as expected (temporarily raise the
   baseline to prove the failure path, then restore it).
6. Continue unit tests on the same branch; rename it from `tests/deferred-unit-tests` to
   `tests/test-infrastructure` when convenient. Rollback is deleting the new CI workflow and test
   files; the clock change can be reverted independently.

## Open Questions

None blocking. The exact set of first unit tests is chosen in follow-up changes as coverage grows.
