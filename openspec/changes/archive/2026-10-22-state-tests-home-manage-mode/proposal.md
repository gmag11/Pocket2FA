# Proposal

## Why

`HomeManageMode` is 104 executable lines at 0% and owns the home screen's
selection and deletion state. It is independent of widget layout and can be
tested directly against a mocked `HomeServerManager`, covering the expensive
branches that are hard to drive through the full home screen.

## What Changes

- Add unit/widget tests for `HomeManageMode`:
  - entering/exiting manage mode and clearing selections;
  - selecting owned accounts and refusing borrowed ones;
  - delete with no selection and with a cancelled confirmation;
  - local-only pending accounts being removed without an API call;
  - no selected server, API-not-ready and successful deletion paths.
- Raise `.coverage-baseline` to the measured overall value after the stage.

No production code, dependencies or public behavior changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This is test-only work; the change declares `skip_specs: true`.

## Impact

- New test `test/unit/screens/home_manage_mode_test.dart`.
- Uses `mocktail` (already a dev dependency) and `pumpApp` for dialog/SnackBar
  context.
- `.coverage-baseline` rises from 49.66 to the measured value (expected around
  50-51%, not guaranteed).
- No `lib/` changes, so the release APK and Android install are unaffected.
- `home_server_manager.dart` and the full home screen remain for later stages.
