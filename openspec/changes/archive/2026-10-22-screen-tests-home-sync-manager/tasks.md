# Tasks

## 1. Force sync

- [x] 1.1 Add success/skipped/network-failure force-sync cases to `test/unit/screens/home_sync_manager_test.dart`; verify with `flutter test test/unit/screens/home_sync_manager_test.dart`.
- [x] 1.2 Assert server reload, reachability updates and refresh suppression.

## 2. Pending uploads

- [x] 2.1 Cover pending-upload success/failure, retry scheduling and backoff reset.
- [x] 2.2 Cover refresh `onRefreshFromPull` and timer disposal.

## 3. Integration and coverage

- [x] 3.1 Run `flutter test --coverage` and verify all 44 files remain instrumented.
- [x] 3.2 Raise `.coverage-baseline` to the measured value, keeping the 70.0 pin.
- [x] 3.3 Run `flutter analyze` and `dart format`; verify no issues and no `lib/` changes.

## Workflow follow-up

- Archive the change after review.
