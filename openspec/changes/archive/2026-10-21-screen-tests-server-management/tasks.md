# Tasks

## 1. Accounts screen

- [x] 1.1 Add `test/widget/accounts_screen_test.dart` with a seeded fake box; assert the server list and verify with `flutter test test/widget/accounts_screen_test.dart`.
- [x] 1.2 Add FAB add, edit and delete dialog flows, including delete cancel/confirm and the empty list after deletion; verify the file passes.
- [x] 1.3 Add server-detail navigation and the locked-storage error surface; verify the file passes.

## 2. Add/edit dialog

- [x] 2.1 Add `test/widget/server_add_edit_dialog_test.dart` with add-mode fields, Cancel and empty-URL validation; verify with `flutter test test/widget/server_add_edit_dialog_test.dart`.
- [x] 2.2 Add edit-mode initial values, API-key clear/reveal and the self-signed switch; verify the file passes.

## 3. Integration and coverage

- [x] 3.1 Run `flutter test --coverage` and verify every test passes and `dart run tool/check_coverage.dart` still reports all 44 non-generated files instrumented.
- [x] 3.2 Raise `.coverage-baseline` to the measured overall value only after the full run, then rerun the gate and verify the ratchet passes at the new floor.
- [x] 3.3 Run `flutter analyze` and `dart format` on the new test files; verify no analyzer issues and no unintended changes under `lib/`.

## Workflow follow-up

- Archive the change after review.
