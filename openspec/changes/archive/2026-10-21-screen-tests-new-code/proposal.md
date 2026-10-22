# Proposal

## Why

`NewCodeScreen` (76 executable lines) and `ImageQrScannerScreen` (59 lines) are
both at 0% and form the guided entry flow: choose camera, image or manual entry,
or pick an image containing a QR code. The settings and log screens are now
covered; these are the next self-contained screens and are testable without
reaching the camera or image picker for their render/navigation paths.

## What Changes

- Add widget tests for `NewCodeScreen`:
  - title, all action buttons and the user/server footer;
  - the camera-unsupported SnackBar on Linux;
  - navigation to `ImageQrScannerScreen`;
  - the back action.
- Add widget tests for `ImageQrScannerScreen`:
  - title, instructions and buttons;
  - the back action.
- Raise `.coverage-baseline` to the measured overall value after the stage.

No production code, dependencies or public behavior changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This is test-only work; the change declares `skip_specs: true`.

## Impact

- New tests under `test/widget/`.
- Reuses `pumpApp` and the existing localization setup; no new dependencies.
- `.coverage-baseline` rises from 44.16 to the measured value (expected around
  45-47%, not guaranteed).
- No `lib/` changes, so the release APK and Android install are unaffected.
- Camera preview, image picking and the advanced form are left for later
  stages because they require platform plugins or a separate large form.
