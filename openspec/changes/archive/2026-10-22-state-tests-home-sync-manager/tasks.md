# Tasks

## 1. Flags and pending state

- [x] 1.1 Add `test/unit/screens/home_sync_manager_test.dart` covering syncing/suppression flags and notifications; verify with `flutter test test/unit/screens/home_sync_manager_test.dart`.
- [x] 1.2 Cover pending-upload detection for all account variants and the selected-server fallback; verify the file passes.

## 2. Retries and guards

- [x] 2.1 Cover retry pause/resume and `ensurePendingUploads` no-pending while preserving the guards; verify the file passes.
- [x] 2.2 Cover force-sync/refresh early returns without reaching `SyncService`; verify the file passes.

## 3. Integration and coverage

- [x] 3.1 Run `flutter test --coverage` and verify every test passes and `dart run tool/check_coverage.dart` still reports all 44 non-generated files instrumented.
- [x] 3.2 Raise `.coverage-baseline` to the measured overall value only after the full run, then rerun the gate and verify the ratchet passes at the new floor.
- [x] 3.3 Run `flutter analyze` and `dart format` on the new test file; verify no analyzer issues and no unintended changes under `lib/`.

## Workflow follow-up

- Archive the change after review.
