# Tasks

## 1. Empty states

- [x] 1.1 Add `test/widget/account_list_test.dart` with no servers configured and assert the add-server state; verify with `flutter test test/widget/account_list_test.dart`.
- [x] 1.2 Add a server-backed empty list and assert the no-accounts state; verify the file passes.

## 2. Filtering and layout

- [x] 2.1 Add populated entries with a deleted one, group and search filters and the no-results state; assert the deleted entry never renders; verify the file passes.
- [x] 2.2 Add a wide-surface grid case and assert the multi-column layout; verify the file passes.

## 3. Interaction

- [x] 3.1 Add manage-mode selection/editing callbacks and the borrowed-account behavior; verify the file passes.
- [x] 3.2 Add a pull-to-refresh case and assert the callback fires; verify the file passes.

## 4. Integration and coverage

- [x] 4.1 Run `flutter test --coverage` and verify every test passes and `dart run tool/check_coverage.dart` still reports all 44 non-generated files instrumented.
- [x] 4.2 Raise `.coverage-baseline` to the measured overall value only after the full run, then rerun the gate and verify the ratchet passes at the new floor.
- [x] 4.3 Run `flutter analyze` and `dart format` on the new test file; verify no analyzer issues and no unintended changes under `lib/`.

## Workflow follow-up

- Archive the change after review.
