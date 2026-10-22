# Tasks

## 1. Entry creation parsing and manual entries

- [x] 1.1 Add `test/unit/services/entry_creation_service_test.dart` covering valid TOTP/HOTP URLs, issuer/label/group rules, colon replacement, Base32 defaults and invalid input; verify with `flutter test test/unit/services/entry_creation_service_test.dart`.
- [x] 1.2 Add tests for `buildManualEntry` (TOTP/HOTP period and counter selection, group fields) and `isValidBase32` (case, padding, separators, invalid characters); verify the same test file passes.

## 2. Entry creation against the API

- [x] 2.1 Add `createEntryOnServer` tests for the empty-host short-circuit and TOTP/HOTP payload shape, including digits, algorithm, period/counter fallbacks and optional group id; verify the recorded `ApiTestHarness` request body and the returned entry.
- [x] 2.2 Add tests for merging server data, group-name resolution from the supplied groups, missing-group fallback, transport failure returning the local entry, and log reset between cases; verify the file passes in isolation.

## 3. Account tile OTP: local paths and lifecycle

- [x] 3.1 Add `test/unit/widgets/account_tile_otp_service_test.dart` covering local TOTP and Steam generation with `withFixedTime`, `refreshUi`, animation callback and initial fields; verify both codes match `OtpService` at the fixed instant.
- [x] 3.2 Add `fake_async` tests for timer disposal and borrowed/empty-seed accounts with `id <= 0` going offline without a request, then retrying after 30 seconds; verify no pending timer remains after `dispose`.

## 4. Account tile OTP: server and HOTP paths

- [x] 4.1 Configure `ApiService.instance` with `ApiTestHarness` and add server-backed refresh tests for success, empty password, API failure, server/local/default period selection and `generated_at` in seconds, milliseconds and string form; verify states and timers.
- [x] 4.2 Add `requestHotp` tests for integer, string and missing counters, success, API failure, the 30-second clear timer and getter values; verify `hotpCode`/`hotpCounter` and `refreshUi` counts.

## 5. Invalid QR feedback

- [x] 5.1 Add `test/widget/entry_creation_snackbar_test.dart` using `pumpApp` to parse an invalid QR with a mounted context and assert the localized error SnackBar and `null` result; verify the test passes with the Flutter binding in its own file.

## 6. Integration and coverage

- [x] 6.1 Run `flutter test --coverage` and verify every test passes and `dart run tool/check_coverage.dart` still reports all 44 non-generated files instrumented.
- [x] 6.2 Raise `.coverage-baseline` to the measured overall value only after the full run, then rerun the gate and verify the ratchet passes at the new floor.
- [x] 6.3 Run `flutter analyze` and `dart format` on the new test files; verify no analyzer issues and no unintended changes under `lib/`.

## Workflow follow-up

- Archive the change after review.
