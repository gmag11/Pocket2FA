# Tasks

## 1. Keypad

- [x] 1.1 Add `test/widget/pin_lock_screen_test.dart` with a fake PIN storage; cover digit entry, delete and submit enablement; verify with `flutter test test/widget/pin_lock_screen_test.dart`.
- [x] 1.2 Cover successful unlock and the `onUnlocked` callback; verify the file passes.
- [x] 1.3 Cover an incorrect PIN and feedback; verify the file passes.

## 2. Lockout and biometrics

- [x] 2.1 Cover the lockout countdown and disabled keypad during the throttle; verify the file passes.
- [x] 2.2 Cover biometric-first success and failure/fallback to the keypad; verify the file passes.

## 3. Input and title

- [x] 3.1 Cover hardware-keyboard digits/backspace/Enter and a custom title; verify the file passes.

## 4. Integration and coverage

- [x] 4.1 Run `flutter test --coverage` and verify every test passes and `dart run tool/check_coverage.dart` still reports all 44 non-generated files instrumented.
- [x] 4.2 Raise `.coverage-baseline` to the measured overall value only after the full run, then rerun the gate and verify the ratchet passes at the new floor.
- [x] 4.3 Run `flutter analyze` and `dart format` on the new test file; verify no analyzer issues and no unintended changes under `lib/`.

## Workflow follow-up

- Archive the change after review.
