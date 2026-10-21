# Tasks

## 1. New code chooser

- [x] 1.1 Add `test/widget/new_code_screen_test.dart` with a tall surface; assert the title, headings, all four buttons and the user/server footer; verify with `flutter test test/widget/new_code_screen_test.dart`.
- [x] 1.2 Tap Scan QR on Linux and assert the camera-unsupported SnackBar; verify the file passes.
- [x] 1.3 Add a route harness: open the chooser, navigate to the image scanner, go back and then pop the chooser; verify the file passes.

## 2. Image scanner

- [x] 2.1 Add `test/widget/image_qr_scanner_screen_test.dart` asserting the title, instruction, gallery button and back button; verify with `flutter test test/widget/image_qr_scanner_screen_test.dart`.
- [x] 2.2 Verify its back button pops to the previous route from the harness; verify the file passes.

## 3. Integration and coverage

- [x] 3.1 Run `flutter test --coverage` and verify every test passes and `dart run tool/check_coverage.dart` still reports all 44 non-generated files instrumented.
- [x] 3.2 Raise `.coverage-baseline` to the measured overall value only after the full run, then rerun the gate and verify the ratchet passes at the new floor.
- [x] 3.3 Run `flutter analyze` and `dart format` on the new test files; verify no analyzer issues and no unintended changes under `lib/`.

## Workflow follow-up

- Archive the change after review.
