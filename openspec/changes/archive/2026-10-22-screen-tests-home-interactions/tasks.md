# Tasks

## 1. Populated home

- [x] 1.1 Add a seeded server/account case to `test/widget/home_screen_test.dart`; verify with `flutter test test/widget/home_screen_test.dart`.
- [x] 1.2 Cover search matching, no-results and manage-mode selection; verify the file passes.
- [x] 1.3 Dispose the page/timers cleanly; verify the file passes.

## 2. Integration and coverage

- [x] 2.1 Run `flutter test --coverage` and verify every test passes and all 44 files remain instrumented.
- [x] 2.2 Raise `.coverage-baseline` to the measured value, keeping the 70.0 pin; verify the ratchet.
- [x] 2.3 Run `flutter analyze` and `dart format`; verify no issues and no `lib/` changes.

## Workflow follow-up

- Archive the change after review.
