# Tasks

## 1. Instrument the whole tree

- [x] 1.1 Add `test/coverage/import_all_test.dart` importing every non-generated `lib/` library, and verify `flutter test test/coverage/import_all_test.dart --coverage` reports zero hits for an otherwise unloaded service.

## 2. Harden the gate

- [x] 2.1 Make `tool/check_coverage.dart` enumerate `lib/**/*.dart` (excluding `lib/l10n/`), fail on missing or uninstrumented files, and print the included file count; verify a clean run reports 44/44.

## 3. Rebase and verify

- [x] 3.1 Rebase `.coverage-baseline` to 15.62, document the metric change, and verify `dart run tool/check_coverage.dart` passes with the full suite.
- [x] 3.2 Run `flutter analyze` and `flutter test --coverage`; verify 145 tests pass and the gate reports the corrected overall and core percentages.

## Workflow follow-up

- Archive the change after review.
