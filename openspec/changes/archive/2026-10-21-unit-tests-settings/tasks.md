# Tasks

## 1. Test harness

- [x] 1.1 Extend `FakeSettingsStorage` with an optional storage-error value and matching `storageError`/`hasStorageError` getters, add a fake test for it, and verify with `flutter test test/unit/services/settings_storage_fake_test.dart`.

## 2. SettingsService loading

- [x] 2.1 Add `test/unit/services/settings_service_test.dart` covering an unlocked storage load: persisted format, enabled, hide-OTP, sync-on-open, auto-sync, interval, debug logging and theme, plus PIN metadata and listener notification; verify with `flutter test test/unit/services/settings_service_test.dart`.
- [x] 2.2 Cover theme migration: `theme_mode` wins over the legacy `dark_mode_enabled`, legacy dark maps to `ThemeMode.dark`, and no stored value maps to `ThemeMode.system`; verify with the same command.
- [x] 2.3 Cover locked storage: defaults are used, PIN metadata is still read, the box is never accessed, and a recorded storage error force-enables debug logging; verify with the same command.

## 3. SettingsService writes

- [x] 3.1 Cover every setter on unlocked storage: values are written to the box and listeners are notified; also verify a setter on locked storage updates memory without touching the box; verify with `flutter test test/unit/services/settings_service_test.dart`.
- [x] 3.2 Cover the `SharedPreferences` fallback: values are persisted, listeners are notified, unknown formats fall back to compact, a non-positive auto-sync interval is ignored, and disabling debug logging clears captured entries; verify with the same command.
- [x] 3.3 Cover the no-storage guards: PIN enable/change/disable and biometric operations return false without throwing; verify with the same command.

## 4. PIN security helpers

- [x] 4.1 Add `test/unit/services/settings_security_test.dart` covering `isValidPin` boundaries (4 and 8 digits accepted, shorter/longer/non-digit rejected); verify with `flutter test test/unit/services/settings_security_test.dart`.
- [x] 4.2 Cover `derivePinHash` with the published PBKDF2-HMAC-SHA256 vector at 1 iteration, a 2-iteration loop case, key length, and salt/PIN sensitivity; verify with the same command.
- [x] 4.3 Cover `constantTimeEquals` for equal, different, and different-length inputs; verify with the same command.

## 5. Verification and baseline

- [x] 5.1 Run `dart format test`, `flutter analyze` and `flutter test --coverage`; verify all tests pass and the analyzer reports no issues.
- [x] 5.2 Run `dart run tool/check_coverage.dart`, verify overall coverage is at least 40.00% and the core metric increased, then raise `.coverage-baseline` to the measured value rounded down to two decimals and rerun the script to confirm it passes.
- [x] 5.3 Verify no production file changed with `git diff --stat -- lib` and record the before/after overall and core percentages in the final summary.

## Workflow follow-up

- Review the test diff, the fake extension and the baseline update.
- Archive the change once the project's review requirements are satisfied.
