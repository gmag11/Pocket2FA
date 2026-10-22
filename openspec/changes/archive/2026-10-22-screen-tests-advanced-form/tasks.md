# Tasks

## 1. Create mode

- [x] 1.1 Add `test/widget/advanced_form_screen_test.dart` with a tall surface; assert the title, create fields and action buttons; verify with `flutter test test/widget/advanced_form_screen_test.dart`.
- [x] 1.2 Cover empty-form validation and valid TOTP field entry; verify the file passes.
- [x] 1.3 Cover TOTP/HOTP/STEAM switching and the period/counter field changes; verify the file passes.
- [x] 1.4 Cover digits, algorithm and group controls; verify the file passes.

## 2. Edit mode and lifecycle

- [x] 2.1 Cover edit-mode prefill, disabled type buttons and the locked secret; verify the file passes.
- [x] 2.2 Cover the borrowed-account automatic pop and the duplicate-submit guard; verify the file passes.

## 3. Submission

- [x] 3.1 Cover local submission with an empty server host, asserting the popped `AccountEntry`; verify the file passes.

## 4. Integration and coverage

- [x] 4.1 Run `flutter test --coverage` and verify every test passes and `dart run tool/check_coverage.dart` still reports all 44 non-generated files instrumented.
- [x] 4.2 Raise `.coverage-baseline` to the measured overall value only after the full run, then rerun the gate and verify the ratchet passes at the new floor.
- [x] 4.3 Run `flutter analyze` and `dart format` on the new test file; verify no analyzer issues and no unintended changes under `lib/`.

## Workflow follow-up

- Archive the change after review.
