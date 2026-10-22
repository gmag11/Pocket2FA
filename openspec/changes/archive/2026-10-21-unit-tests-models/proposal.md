# Proposal

## Why

Overall coverage is 20.20%, and three data models that sit on the boundary between
Hive/API payloads and the UI (`GroupEntry`, `ServerConnection`, `UserPreferences`)
have 0% coverage. Their `fromMap` implementations coerce types and apply defaults
for legacy payloads; a silent regression there (for example the
`AutoSaveQrcodedAccount` key with a capital A) corrupts persisted settings without
any analyzer or UI error.

Model tests are the cheapest next increment: pure Dart, no platform plugins, no
network, and fast enough to run on every change.

## What Changes

- Add unit tests for `GroupEntry`: map round-trip, numeric strings, missing or null
  values, and `toString`.
- Add unit tests for `UserPreferences`: round-trip of all 33 fields, defaults for
  absent fields, boolean/numeric string coercion, and the legacy/capitalized keys.
- Add unit tests for `ServerConnection`: round-trip with accounts, groups and
  preferences, optional-field omission in `toMap`, defaults in `fromMap`, and
  numeric `user_id` coercion.
- Add a small test-only builder for `UserPreferences` so each case states only the
  field under test.
- Raise `.coverage-baseline` to the measured overall percentage (expected around
  30%) after the new tests pass.

No production code changes, no new dependencies, and no service, widget, or network
tests in this stage.

## Capabilities

### New Capabilities

None. This change only adds tests; no system behavior changes, so the change
declares `skip_specs: true`.

### Modified Capabilities

None.

## Impact

- New tests under `test/unit/models/`.
- `.coverage-baseline` updated to the new measured value.
- No changes to `lib/`, `pubspec.yaml`, or CI workflows.
