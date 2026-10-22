# Tasks

## 1. Log content

- [x] 1.1 Add `test/widget/log_screen_test.dart` with an empty-log case asserting the localized empty state; verify with `flutter test test/widget/log_screen_test.dart`.
- [x] 1.2 Seed debug/info/warning/error entries and assert their messages, source names and level badges; verify the file passes.

## 2. Filtering

- [x] 2.1 Open the filter menu, select ERROR, assert only the error message remains, then select All and assert every message returns; verify the file passes.

## 3. Actions

- [x] 3.1 Mock the clipboard, tap Copy, assert the report text and the copied SnackBar, and reset the channel afterward; verify the file passes.
- [x] 3.2 Open the clear dialog, cancel it and assert the entries remain; repeat, confirm, and assert the empty state; verify the file passes.
- [x] 3.3 Seed enough entries to scroll, tap the scroll-to-bottom FAB and pump the animation without exceptions; verify the file passes.

## 4. Integration and coverage

- [x] 4.1 Run `flutter test --coverage` and verify every test passes and `dart run tool/check_coverage.dart` still reports all 44 non-generated files instrumented.
- [x] 4.2 Raise `.coverage-baseline` to the measured overall value only after the full run, then rerun the gate and verify the ratchet passes at the new floor.
- [x] 4.3 Run `flutter analyze` and `dart format` on the new test file; verify no analyzer issues and no unintended changes under `lib/`.

## Workflow follow-up

- Archive the change after review.
