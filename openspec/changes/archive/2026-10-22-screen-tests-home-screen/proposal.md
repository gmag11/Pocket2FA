# Proposal

## Why

`home_screen.dart` is the largest remaining file: 616 executable lines at 0%.
All of its collaborators (server manager, sync manager, manage mode, account
list, tiles, settings) are now covered, so a first home-page widget test can
exercise the real composition and empty/storage-driven startup without mocks
for each child.

## What Changes

- Add a first `HomePage` widget test suite:
  - empty-storage startup and the no-server/empty account state;
  - header, search bar, bottom bar and floating action button rendering;
  - settings/about/accounts navigation targets where reachable;
  - dispose of timers and animation controllers cleanly.
- Raise `.coverage-baseline` to the measured overall value (pinned at 70 if
  already above it).

No production code, dependencies or public behavior changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This is test-only work; the change declares `skip_specs: true`.

## Impact

- New test `test/widget/home_screen_test.dart`.
- Reuses `pumpApp`, `FakeSettingsStorage` and the covered child widgets; no new
  dependencies.
- `.coverage-baseline` stays pinned at 70.0 or rises to the measured value.
- No `lib/` changes, so the release APK and Android install are unaffected.
- Incoming share/drop and live sync flows remain for later stages.
