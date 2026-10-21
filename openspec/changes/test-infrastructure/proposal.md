# Proposal

## Why

Pocket2FA has no automated test suite: there is no `test/` directory, `flutter_test` is not in
`dev_dependencies`, and CI only builds artifacts. Recent fixes (for example the shared-account OTP
and secure-storage dead-end issues) were shipped without regression protection; two tests written
for them were deliberately deferred to the `tests/deferred-unit-tests` branch because the test
dependency was out of scope at release time. The goal is to reach 70% coverage of `lib/`, starting
with unit tests, and to make coverage visible and non-regressing from the first day.

## What Changes

- Add the test toolchain: `flutter_test` (SDK), `mocktail`, `fake_async`, and
  `http_mock_adapter` as dev dependencies, plus `clock` as a runtime dependency.
- Introduce deterministic time in `OtpService` and `LogService` by replacing direct
  `DateTime.now()` calls with `clock.now()`. The default clock preserves current behavior.
- Create a test layout that supports both phases: `test/unit/` (models and services now),
  `test/widget/` (screens and widgets later), `test/helpers/` (fakes, pump helper, clock helper)
  and `test/fixtures/` (2FAuth payloads).
- Add `tool/check_coverage.dart`: parses `coverage/lcov.info`, excludes generated `lib/l10n/`,
  and reports overall coverage plus the unit-testable core (`lib/models` + `lib/services`).
- Add `.coverage-baseline` and a ratchet check: CI fails when coverage drops below the stored
  baseline; the baseline is raised deliberately as coverage grows and is fixed at 70% once
  reached.
- Add `.github/workflows/test.yml` running `flutter analyze`, `flutter test --coverage`, and the
  coverage ratchet on push and pull request.
- Recover the two deferred tests from `tests/deferred-unit-tests` history as the first suite that
  exercises the new harness. Development continues on that branch, renamed if desired.
- No user-visible behavior changes.

## Capabilities

### New Capabilities

- `testing-infrastructure`: test suite layout, hermetic unit testing, deterministic time for
  time-dependent services, coverage measurement that excludes generated code, and the CI coverage
  ratchet.

### Modified Capabilities

None.

## Impact

- `pubspec.yaml` / `pubspec.lock`: new dependencies (`flutter_test`, `mocktail`, `fake_async`,
  `http_mock_adapter`, `clock`).
- `lib/services/otp_service.dart`, `lib/services/log_service.dart`: use the injectable clock.
- New `test/`, `tool/check_coverage.dart`, `.coverage-baseline`, and
  `.github/workflows/test.yml`.
- CI gains a test job; existing build workflows are unchanged.
- Git: work happens on the existing `tests/deferred-unit-tests` branch (rename optional).
