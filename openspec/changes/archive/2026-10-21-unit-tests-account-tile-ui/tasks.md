# Tasks

## 1. OTP formatting and colors

- [x] 1.1 Add `test/unit/widgets/account_tile_utils_test.dart` with `formatCode` cases for compact, spaced3, spaced2, enabled=false, hidden OTPs, forced visibility, whitespace, offline text and short-group tails; verify with `flutter test test/unit/widgets/account_tile_utils_test.dart`.
- [x] 1.2 Add `getServiceColor` cases for a stable service color, account-name fallback, empty fallback and the character-sum index; verify the same file passes.

## 2. Tile animations

- [x] 2.1 Add `test/widget/account_tile_animations_test.dart` covering start duration, initial value range, controller replacement, `stopAnimation` and `dispose`; verify the file passes.
- [x] 2.2 Add zero and negative period cases to confirm the 30-second fallback; verify the file passes.

## 3. Reusable tile UI

- [x] 3.1 Add `test/widget/account_tile_ui_test.dart` with avatar fallbacks for service/account/empty names plus temporary non-SVG and SVG local icons; verify the file passes.
- [x] 3.2 Add shared-indicator, HOTP button and HOTP display tests, including copy callbacks, settings/no-settings formatting and counter text; verify the same file passes.
- [x] 3.3 Add progress-dot tests with a null controller and a live `AnimationController`, and dispose the controller afterward; verify the same file passes.

## 4. Tile dispatch and pending badge

- [x] 4.1 Add `AccountTile` dispatch tests for TOTP and HOTP items; replace the tree with `SizedBox` afterward so timers are disposed; verify the tests pass.
- [x] 4.2 Add a synchronized=false test asserting the pending-upload badge/tooltip and a synchronized=true test asserting its absence; verify the tests pass.

## 5. Integration and coverage

- [x] 5.1 Run `flutter test --coverage` and verify every test passes and `dart run tool/check_coverage.dart` still reports all 44 non-generated files instrumented.
- [x] 5.2 Raise `.coverage-baseline` to the measured overall value only after the full run, then rerun the gate and verify the ratchet passes at the new floor.
- [x] 5.3 Run `flutter analyze` and `dart format` on the new test files; verify no analyzer issues and no unintended changes under `lib/`.

## Workflow follow-up

- Archive the change after review.
