# Tasks

## 1. GroupEntry

- [x] 1.1 Add `test/unit/models/group_entry_test.dart` covering `toMap`/`fromMap` round-trip, numeric strings, missing and null values, and `toString`; verify with `flutter test test/unit/models/group_entry_test.dart`.

## 2. UserPreferences

- [x] 2.1 Add `test/unit/models/user_preferences_test.dart` with a local `preferencesWith(...)` builder so each case overrides only the field under test; verify the file compiles with `flutter analyze test/unit/models/user_preferences_test.dart`.
- [x] 2.2 Cover the full round-trip: every one of the 33 fields survives `toMap`/`fromMap`, including the `revealDottedOTP` and `AutoSaveQrcodedAccount` keys; verify with `flutter test test/unit/models/user_preferences_test.dart`.
- [x] 2.3 Cover defaults for absent fields, boolean and numeric string coercion, and both legacy/capitalized keys; verify with the same test command and check every assertion is green.

## 3. ServerConnection

- [x] 3.1 Add `test/unit/models/server_connection_test.dart` covering a full round-trip with accounts, groups and preferences; verify nested models keep their values with `flutter test test/unit/models/server_connection_test.dart`.
- [x] 3.2 Cover optional-field omission in `toMap`, `fromMap` defaults (`userEmail` empty, `allowSelfSigned` false), numeric `user_id` coercion, and payloads without groups or preferences; verify with the same test command.

## 4. Verification and baseline

- [x] 4.1 Run `dart format test/unit/models`, `flutter analyze` and `flutter test --coverage`; verify all tests pass and analyzer reports no issues.
- [x] 4.2 Run `dart run tool/check_coverage.dart`, verify overall coverage is at least 30.00% and the core metric increased, then raise `.coverage-baseline` to the measured value rounded down to two decimals and rerun the script to confirm it passes.
- [x] 4.3 Verify no production file changed with `git diff --stat -- lib` and record the before/after overall and core percentages in the final summary.

## Workflow follow-up

- Review the test diff and commit the new tests with the baseline update.
- Archive the change once the project's review requirements are satisfied.
