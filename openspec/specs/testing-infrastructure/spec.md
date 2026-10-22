# testing-infrastructure Specification

## Purpose

Define how Pocket2FA protects its behavior with an automated test suite: hermetic unit tests,
deterministic time, coverage that ignores generated code, and a CI gate that prevents coverage
from regressing on the way to 70% of `lib/`.

## Requirements

### Requirement: Tests run hermetically

The test suite SHALL run on a clean checkout without a device, emulator, or configured platform
plugin, using only the Flutter SDK test runner and declared test dependencies.

#### Scenario: Unit suite runs without platform services

- **WHEN** `flutter test` runs on a machine with no emulator, no network, and no platform plugin
  configuration
- **THEN** every test in `test/unit/` passes without invoking Hive, secure storage, biometrics,
  shared preferences, or any other platform channel

#### Scenario: Test dependencies are declared

- **WHEN** a developer runs `flutter pub get` on a clean checkout
- **THEN** every package needed to run the test suite is declared in `pubspec.yaml` and no test
  requires a separate manual setup step

### Requirement: Time-dependent behavior is deterministic

Code that produces timestamps or derives values from the current time SHALL read time from an
injectable clock so tests can fix it, while production behavior continues to use the real system
clock by default.

#### Scenario: OTP generation at a fixed instant

- **WHEN** a test fixes the clock to a published RFC 6238 timestamp and generates a TOTP code
- **THEN** the returned code matches the published vector and does not change between runs

#### Scenario: Log entries use the fixed clock

- **WHEN** the clock is fixed and a log entry is captured
- **THEN** the entry timestamp equals the fixed instant

### Requirement: Coverage excludes generated code

Coverage measurement SHALL exclude generated localization sources from both the covered lines and
the total line count, and SHALL report the overall project coverage and the unit-testable core
(`lib/models` and `lib/services`) separately.

#### Scenario: Generated localization is ignored

- **WHEN** coverage is computed from a run that executes code under `lib/`
- **THEN** files under `lib/l10n/` do not appear in the coverage total and cannot lower or raise
  the reported percentage

#### Scenario: Both metrics are reported

- **WHEN** the coverage report is produced
- **THEN** it shows the percentage for all non-generated `lib/` code and the percentage for the
  unit-testable core separately

### Requirement: Coverage cannot regress

Continuous integration SHALL compare the measured coverage against a stored baseline and fail
when coverage drops below it. The baseline SHALL only move upward, and once overall coverage
reaches 70% it SHALL remain pinned at 70%.

#### Scenario: Coverage drop fails the check

- **WHEN** a change lowers overall coverage below the stored baseline
- **THEN** the CI test job fails and reports the measured value and the baseline

#### Scenario: Coverage increase is accepted

- **WHEN** a change raises coverage at or above the baseline
- **THEN** the CI test job passes and the baseline may be raised deliberately in the same change

#### Scenario: Target is reached

- **WHEN** overall coverage reaches or exceeds 70%
- **THEN** the baseline is fixed at 70% and later changes cannot lower it
