# Proposal

## Why

`window_geometry_service.dart` is 127 executable lines at 0% and is the desktop
window persistence layer. It restores geometry, debounces resize/move events,
saves bounds and handles the close handshake. The singleton and platform
channels make it untested.

## What Changes

- Add a test for `WindowGeometryService` with mocked `window_manager` channels
  and shared preferences:
  - `isSupportedPlatform` on the test host;
  - `init` restoring the default bounds and registering the close guard;
  - `showWindow` re-applying bounds and focusing;
  - debounced resize saving bounds;
  - the close handshake saving, disabling prevent-close and closing.
- Raise `.coverage-baseline` to the measured overall value after the stage.

No production code, dependencies or public behavior changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This is test-only work; the change declares `skip_specs: true`.

## Impact

- New test `test/services/window_geometry_service_test.dart`.
- Mock `window_manager` and shared preferences; no new dependencies.
- `.coverage-baseline` rises from 67.51 to the measured value (expected around
  69-70%, not guaranteed).
- No `lib/` changes, so the release APK and Android install are unaffected.
- Wayland-specific geometry and screen-retriever clamping remain for a later
  stage because they require a non-default environment.
