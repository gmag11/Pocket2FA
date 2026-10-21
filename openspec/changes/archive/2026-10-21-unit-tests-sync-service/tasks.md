# Tasks

## 1. Test harness and sync throttle

- [x] 1.1 Add `test/unit/services/sync_service_test.dart` with the storage/API helpers, `setUp`/`tearDown` cleanup and a first `syncIfNeeded` test for a recent non-forced sync; assert the exact skipped result and that no request is made. Verify with `flutter test test/unit/services/sync_service_test.dart`.
- [x] 1.2 Add `syncIfNeeded` tests for a recent forced sync, an old timestamp, a corrupt/non-string timestamp, a missing timestamp and locked storage; assert whether `forceSync` ran and how the result propagates. Verify the same file passes.

## 2. Fetch, merge and persistence

- [x] 2.1 Add a `forceSync` happy-path test with groups and accounts: assert `withSecret=true`, group-name mapping, replacement of the matching persisted server, last-sync keys and the success summary. Verify the file passes.
- [x] 2.2 Add fetch-failure tests for a non-list/error groups response and a non-list/error/HTTP-500 accounts response; assert the network-failure result and that no last-sync key is written. Verify the file passes.
- [x] 2.3 Add merge/filter tests: a fetched account matching a pending delete is removed, a local-only pending create survives a failed upload plus fetch, and malformed or locked `servers` data does not crash or persist timestamps. Verify the file passes.

## 3. Pending creates

- [x] 3.1 Add `uploadPendingAccounts` success tests: assert the POST payload, returned count, merged server id, synchronized flag, group-name resolution and preserved local secret in storage. Verify the file passes.
- [x] 3.2 Add `uploadPendingAccounts` edge cases: missing response id, API failure, no pending entries, no matching server, locked storage and malformed storage; assert zero uploads and unchanged or safely handled storage. Verify the file passes.

## 4. Pending deletes and updates

- [x] 4.1 Add `forceSync` delete tests: successful DELETE removes the tombstone, a local-only tombstone is purged without a DELETE request, and no pending delete means no DELETE. Verify storage and request paths.
- [x] 4.2 Add a `forceSync` update test: successful PUT merges the response, keeps the local icon and resolves the group name from the local server groups; verify the persisted account and request body.
- [x] 4.3 Add update failure tests for a response without `id` and an API exception; assert the account remains unchanged and unsynchronized.

## 5. Summaries and icon cancellation

- [x] 5.1 Add tests for the no-icon success summary (`all_ok`, completion message, zero counters) and icon-download cancellation via an interceptor that cancels after the accounts response; assert the icon service is never called and the summary counts stay zero.

## 6. Integration and coverage

- [x] 6.1 Run `flutter test --coverage` and verify every test passes and `dart run tool/check_coverage.dart` still reports all 44 non-generated files instrumented.
- [x] 6.2 Raise `.coverage-baseline` to the measured overall value only after the full run, then rerun the gate and verify the ratchet passes at the new floor.
- [x] 6.3 Run `flutter analyze` and `dart format` on the new test file; verify no analyzer issues and no unintended changes under `lib/`.

## Workflow follow-up

- Archive the change after review.
