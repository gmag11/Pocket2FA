# Tasks

## 1. Toolchain and dependencies

- [x] 1.1 Add `flutter_test` (SDK), `mocktail`, `fake_async`, and `http_mock_adapter` to `dev_dependencies`, and `clock` to `dependencies`; verify `flutter pub get` completes and `flutter analyze` reports no new issues.
- [x] 1.2 Add a minimal smoke test at `test/unit/smoke_test.dart` that imports `package:pocket2fa/services/otp_service.dart`; verify `flutter test test/unit/smoke_test.dart` runs and passes with no device attached.

## 2. Deterministic time

- [x] 2.1 Replace `DateTime.now()` with `clock.now()` in `lib/services/otp_service.dart` and `lib/services/log_service.dart`; verify `flutter analyze` passes and no other direct `DateTime.now()` call remains in those files.
- [x] 2.2 Add `test/helpers/clock.dart` with a fixed-clock helper, and unit tests asserting an RFC 6238 TOTP vector for a fixed timestamp and a fixed timestamp on a captured log entry; verify both tests pass and produce identical results on repeated runs.

## 3. Test harness

- [x] 3.1 Create the `test/unit/{models,services}`, `test/widget`, `test/helpers`, and `test/fixtures` layout; verify `flutter test` discovers files in all unit directories (empty directories may need a placeholder test until phase 2).
- [x] 3.2 Implement `FakeSettingsStorage` in `test/helpers/fakes/` overriding only the members tests need (`box`, `isUnlocked`, `hasPin`, `pinLength`, `supportsBiometrics`); verify a unit test reads and writes through the fake without initializing Hive.
- [x] 3.3 Add `pumpApp()` in `test/helpers/pump.dart` wrapping a widget in `MaterialApp` with the app localization delegates and a test `SettingsService`; verify one widget smoke test renders a simple localized widget without platform channels.
- [x] 3.4 Add `test/helpers/` reset utilities for `LogService.instance` and `SettingsService`, and cover them with a test that runs two cases in sequence without state leaking between them.

## 4. Seed suite from deferred tests

- [x] 4.1 Recover `test/shared_account_otp_test.dart` and `test/secure_storage_dead_end_test.dart` from commit `5fd1a4c0`, move them under `test/unit/`, and adapt imports/helpers to the new harness; verify both files pass with `flutter test`.
- [x] 4.2 Add fixture JSON under `test/fixtures/` for a borrowed (shared) account payload and an owned account payload, and a test parsing them through `AccountEntry.fromMap`; verify the test asserts `isBorrowed`, `sharedBy`, and the default values.

## 5. Coverage tooling and ratchet

- [x] 5.1 Implement `tool/check_coverage.dart` to parse `coverage/lcov.info`, exclude `lib/l10n/`, report overall and `models`+`services` coverage, compare against `.coverage-baseline`, and exit non-zero on a drop; verify it prints both metrics after `flutter test --coverage`.
- [x] 5.2 Initialize `.coverage-baseline` with the measured overall coverage; verify the script exits 0 at the baseline and exits non-zero when the baseline is temporarily raised above the measured value (then restore it).
- [x] 5.3 Add a short comment in `.coverage-baseline`/script header documenting the ratchet rule and the 70% ceiling; verify the target is printed by the script output.

## 6. CI integration

- [x] 6.1 Add `.github/workflows/test.yml` running on `push` and `pull_request` with Flutter `3.47.7`: `flutter pub get`, `flutter analyze`, `flutter test --coverage`, and `dart run tool/check_coverage.dart`; verify the YAML is valid and the same four commands pass locally.
- [x] 6.2 Confirm the gate behavior on CI: open the branch's first run, verify the job is green at the baseline, then verify a deliberately lowered coverage (temporary, reverted) turns the job red.

## 7. Integration check

- [x] 7.1 Run `flutter analyze`, `flutter gen-l10n`, `flutter test --coverage`, and `dart run tool/check_coverage.dart` end to end; verify all pass and the reported coverage matches the baseline.
- [x] 7.2 Verify the existing build workflows and `lib/` runtime behavior are unchanged apart from the clock source by reviewing the diff and confirming no user-visible behavior changed.

## Workflow follow-up

- Rename the working branch from `tests/deferred-unit-tests` to `tests/test-infrastructure` when convenient.
- Archive the change after review and after the CI workflow has run green on the branch. No pull request is opened as part of this change.
