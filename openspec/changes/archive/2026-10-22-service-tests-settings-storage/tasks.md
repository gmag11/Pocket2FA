# Tasks

## 1. Platform doubles

- [x] 1.1 Add an in-memory secure-storage fake and a controllable local-auth fake for the settings-storage tests; verify they compile with `flutter test test/unit/services/settings_storage_test.dart`.
- [x] 1.2 Add the temp-directory/path-provider setup and a fresh storage per test; verify a fresh init opens the box.

## 2. Lifecycle

- [x] 2.1 Cover empty secure storage key generation and existing-key reuse; verify the file passes.
- [x] 2.2 Cover secure-storage failure, locked state and retry; verify the file passes.

## 3. PIN and biometrics

- [x] 3.1 Cover PIN set/verify/change/clear, wrong PIN and lockout countdown/reset; verify the file passes.
- [x] 3.2 Cover biometric enable/disable, unsupported/cancelled prompts and key release; verify the file passes.
- [x] 3.3 Cover `readKey` with and without auth and box read/write helpers; verify the file passes.

## 4. Integration and coverage

- [x] 4.1 Run `flutter test --coverage` and verify every test passes and `dart run tool/check_coverage.dart` still reports all 44 non-generated files instrumented.
- [x] 4.2 Raise `.coverage-baseline` to the measured overall value, pinning at 70.0 if reached; verify the ratchet passes.
- [x] 4.3 Run `flutter analyze` and `dart format` on the new test files; verify no analyzer issues and no unintended changes under `lib/`.

## Workflow follow-up

- Archive the change after review.
