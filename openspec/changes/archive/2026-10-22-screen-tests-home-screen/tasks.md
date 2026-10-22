# Tasks

## 1. Empty startup

- [x] 1.1 Add `test/widget/home_screen_test.dart` with empty fake storage and a mocked app-support directory; pump the real `HomePage`; verify with `flutter test test/widget/home_screen_test.dart`.
- [x] 1.2 Assert the empty/no-server state, search field, bottom bar and add FAB; verify the file passes.
- [x] 1.3 Cover reachable settings/accounts navigation and dispose the page cleanly; verify the file passes.

## 2. Integration and coverage

- [x] 2.1 Run `flutter test --coverage` and verify every test passes and `dart run tool/check_coverage.dart` still reports all 44 non-generated files instrumented.
- [x] 2.2 Raise `.coverage-baseline` to the measured overall value, keeping the 70.0 pin if applicable; verify the ratchet passes.
- [x] 2.3 Run `flutter analyze` and `dart format` on the new test file; verify no analyzer issues and no unintended changes under `lib/`.

## Workflow follow-up

- Archive the change after review.
