# Tasks

## 1. Warning and new PIN

- [x] 1.1 Add `test/widget/pin_settings_dialogs_test.dart` covering the forgot-PIN warning cancel/accept results; verify with `flutter test test/widget/pin_settings_dialogs_test.dart`.
- [x] 1.2 Cover new-PIN invalid length, mismatch, valid and cancel results; verify the file passes.

## 2. Current factor

- [x] 2.1 Cover the empty current PIN error, cancel result and absence of the biometrics action; verify the file passes.

## 3. Integration and coverage

- [x] 3.1 Run `flutter test --coverage` and verify every test passes and `dart run tool/check_coverage.dart` still reports all 44 non-generated files instrumented.
- [x] 3.2 Raise `.coverage-baseline` to the measured overall value only after the full run, then rerun the gate and verify the ratchet passes at the new floor.
- [x] 3.3 Run `flutter analyze` and `dart format` on the new test file; verify no analyzer issues and no unintended changes under `lib/`.

## Workflow follow-up

- Archive the change after review.
