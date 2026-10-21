# Tasks

## 1. General settings

- [x] 1.1 Add `test/widget/settings_screen_test.dart` with a tall surface and a `FakeSettingsStorage`-backed service; assert the title and section headers and verify with `flutter test test/widget/settings_screen_test.dart`.
- [x] 1.2 Add theme selection through the segmented control and assert `SettingsService.themeMode`; verify the file passes.
- [x] 1.3 Add code-formatting enable/disable and spaced2/spaced3 selection, asserting the service values and the visible format buttons; verify the file passes.

## 2. Security settings

- [x] 2.1 Add the biometrics-unsupported tooltip/disabled switch case and assert the PIN row when `pinEnabled` is true; verify the file passes.
- [x] 2.2 Add the hide-OTP switch case and assert `SettingsService.hideOtps`; verify the file passes.

## 3. Synchronization and diagnostics

- [x] 3.1 Add sync-on-open and automatic-sync switches, assert the service values and verify the interval selector appears when automatic sync is enabled; verify the file passes.
- [x] 3.2 Add interval add/remove cases asserting 31 and back to 30 minutes; verify the file passes.
- [x] 3.3 Add the debug-logging switch, assert the diagnostic-log button appears, tap it and assert `LogScreen`; verify the file passes.

## 4. Theme and integration

- [x] 4.1 Add a dark-theme render case and verify the screen builds without exceptions; verify the file passes.
- [x] 4.2 Run `flutter test --coverage` and verify every test passes and `dart run tool/check_coverage.dart` still reports all 44 non-generated files instrumented.
- [x] 4.3 Raise `.coverage-baseline` to the measured overall value only after the full run, then rerun the gate and verify the ratchet passes at the new floor.
- [x] 4.4 Run `flutter analyze` and `dart format` on the new test file; verify no analyzer issues and no unintended changes under `lib/`.

## Workflow follow-up

- Archive the change after review.
