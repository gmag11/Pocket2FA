# Tasks

## 1. OTP service

- [x] 1.1 Extend `test/unit/services/otp_service_test.dart` with unsupported and HOTP types returning an empty code, plus a spaced/padded Base32 secret matching the RFC vector; verify with `flutter test test/unit/services/otp_service_test.dart`.
- [x] 1.2 Cover `base32Decode` (case folding, padding/ignored characters, empty input) and `pow10` edge values; verify with the same command.
- [x] 1.3 Cover the MD5 algorithm path: a 6-digit code that differs from SHA-1 for the same account and instant; verify with the same command.
- [x] 1.4 Cover the Steam path: `generateOtp` with `steamtotp` matches `generateSteamTotp` on the decoded secret, produces 5 charset characters, is deterministic, changes with a period offset, and returns empty for empty or invalid Base64 secrets; verify with the same command.

## 2. Log service

- [x] 2.1 Extend `test/unit/services/log_service_test.dart` with every `LogEntry` level tag, `toString` formatting, and the debug/info/warning/error shortcuts; verify with `flutter test test/unit/services/log_service_test.dart`.
- [x] 2.2 Cover the 1000-entry cap (oldest evicted) and the delayed `entryCount` notification using `testWidgets` and `tester.pump()`; verify with the same command.
- [x] 2.3 Cover `exportAsText` with a fixed clock: header, platform line, separator, and each captured entry; verify with the same command.
- [x] 2.4 Cover `exportToFile` success and failure by mocking the `plugins.flutter.io/path_provider` channel to a temporary directory and to an error, cleaning up the file in `tearDown`; verify with the same command.

## 3. Verification and baseline

- [x] 3.1 Run `dart format test/unit/services/otp_service_test.dart test/unit/services/log_service_test.dart`, `flutter analyze` and `flutter test --coverage`; verify all tests pass and the analyzer reports no issues.
- [x] 3.2 Run `dart run tool/check_coverage.dart`, verify overall coverage is at least 46.00% and the core metric increased, then raise `.coverage-baseline` to the measured value rounded down to two decimals and rerun the script to confirm it passes.
- [x] 3.3 Verify that `git diff --stat -- lib` only contains the intended dead-code removal in `otp_service.dart`, and record the before/after overall and core percentages in the final summary.

## 4. Dead code removal

- [x] 4.1 Simplify `_decodeSecret` to Base32 only and remove the unused `_hotp` stub plus the commented-out HOTP persistence helpers; verify `flutter test test/unit/services/otp_service_test.dart` stays green.
- [x] 4.2 Run `flutter analyze` and `flutter test --coverage`, verify OTP coverage reaches 100%, then raise `.coverage-baseline` to the new measured value and rerun `dart run tool/check_coverage.dart`.

## Workflow follow-up

- Review the test diff and the baseline update.
- Archive the change once the project's review requirements are satisfied.
