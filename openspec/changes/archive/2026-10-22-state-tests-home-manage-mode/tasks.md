# Tasks

## 1. Selection state

- [x] 1.1 Add `test/unit/screens/home_manage_mode_test.dart` covering mode toggling, selection clearing and change notifications; verify with `flutter test test/unit/screens/home_manage_mode_test.dart`.
- [x] 1.2 Cover owned-account selection/deselection and borrowed-account rejection; verify the file passes.

## 2. Deletion flows

- [x] 2.1 Cover no selection and cancelled confirmation, asserting the manager is unchanged; verify the file passes.
- [x] 2.2 Cover local-only pending deletion, missing selected server and API-not-ready branches; verify the file passes.
- [x] 2.3 Cover a successful API deletion with `ApiTestHarness`, asserting the final in-memory server and reachability; verify the file passes.

## 3. Integration and coverage

- [x] 3.1 Run `flutter test --coverage` and verify every test passes and `dart run tool/check_coverage.dart` still reports all 44 non-generated files instrumented.
- [x] 3.2 Raise `.coverage-baseline` to the measured overall value only after the full run, then rerun the gate and verify the ratchet passes at the new floor.
- [x] 3.3 Run `flutter analyze` and `dart format` on the new test file; verify no analyzer issues and no unintended changes under `lib/`.

## Workflow follow-up

- Archive the change after review.
