# Tasks

## 1. Loading and selection

- [x] 1.1 Add `test/unit/screens/home_server_manager_test.dart` covering stored-server loading, selection restoration and deleted-entry filtering; verify with `flutter test test/unit/screens/home_server_manager_test.dart`.
- [x] 1.2 Cover empty storage, intentional-empty, cached-fallback and unknown-selection branches; verify the file passes.
- [x] 1.3 Cover duplicate pending-id normalization and persistence; verify the file passes.

## 2. Selection and persistence

- [x] 2.1 Cover valid/invalid `selectServer`, `selected` persistence and `persistServersToStorage`; verify the file passes.
- [x] 2.2 Cover locked-storage no-op persistence; verify the file passes.

## 3. Account mutations

- [x] 3.1 Cover `insertCreatedAccount` missing-server, replace, append and negative-id cases; verify the file passes.
- [x] 3.2 Cover `addNewAccount`, `updateAccount`, `updateServersInMemory` and `getSelectedServer`; verify the file passes.

## 4. Groups and integration

- [x] 4.1 Cover `getGroups` and `getGroupKey`; verify the file passes.
- [x] 4.2 Run `flutter test --coverage`, update `.coverage-baseline` to the measured value and verify the ratchet passes with 44/44 files.
- [x] 4.3 Run `flutter analyze` and `dart format` on the new test file; verify no analyzer issues and no changes under `lib/`.

## Workflow follow-up

- Archive the change after review.
