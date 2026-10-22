# Tasks

## 1. TOTP normal mode

- [x] 1.1 Add `test/widget/account_tile_totp_test.dart` with a fixed-clock pump and the RFC seed; assert the service/account, the current `94287082` and the computed next code; verify with `flutter test test/widget/account_tile_totp_test.dart`.
- [x] 1.2 Add clipboard capture for tapping the current code and the next code, asserting the SnackBars and the digit-only clipboard payload; verify the file passes.
- [x] 1.3 Add an offline/borrowed-account case that shows no code, taps the tile and asserts the no-code SnackBar; verify the file passes.
- [x] 1.4 Add a clipboard-failure case that throws `PlatformException` and asserts the error SnackBar; verify the file passes.

## 2. TOTP hidden codes and manage mode

- [x] 2.1 Add a hidden-OTP case with `SettingsService.setHideOtps(true)`: long-press the current code, assert it is revealed, pump 10 seconds and assert it is masked again; repeat for the next code; verify the file passes.
- [x] 2.2 Add manage-mode tests for the checkbox value, `onToggleSelection`, the edit icon and `onEdit`, plus borrowed accounts having no checkbox; verify the file passes.
- [x] 2.3 Add a case with `onEdit == null` and a wide surface (`1300x800`) asserting the 520-wide `ConstrainedBox`; verify the file passes.
- [x] 2.4 Add a `didUpdateWidget` case that changes the account under the same tile type, asserts the new account text and disposes the tile; verify the file passes.

## 3. HOTP normal mode

- [x] 3.1 Add `test/widget/account_tile_hotp_test.dart` with an initial Generate button and a mocked `twofaccounts/<id>/otp` response; assert the code and counter after tapping Generate; verify with `flutter test test/widget/account_tile_hotp_test.dart`.
- [x] 3.2 Add clipboard capture for tapping the generated code and assert the copied SnackBar; verify the file passes.
- [x] 3.3 Add a hidden-OTP long-press case that reveals the HOTP code and re-hides it after 10 seconds; verify the file passes.
- [x] 3.4 Add the 30-second auto-clear back to the Generate button; verify the file passes.
- [x] 3.5 Add an HTTP 500 case that shows `offline` and clears back to Generate after 30 seconds; verify the file passes.

## 4. HOTP manage mode and lifecycle

- [x] 4.1 Add manage-mode tests for the checkbox value, `onToggleSelection`, the edit icon and `onEdit`, plus borrowed accounts having no checkbox; verify the file passes.
- [x] 4.2 Add a wide-surface case asserting the 520-wide `ConstrainedBox`; verify the file passes.
- [x] 4.3 Add a `didUpdateWidget` case that changes the account under the same tile type, asserts the new account text and disposes the tile; verify the file passes.

## 5. Integration and coverage

- [x] 5.1 Run `flutter test --coverage` and verify every test passes and `dart run tool/check_coverage.dart` still reports all 44 non-generated files instrumented.
- [x] 5.2 Raise `.coverage-baseline` to the measured overall value only after the full run, then rerun the gate and verify the ratchet passes at the new floor.
- [x] 5.3 Run `flutter analyze` and `dart format` on the new test files; verify no analyzer issues and no unintended changes under `lib/`.

## Workflow follow-up

- Archive the change after review.
