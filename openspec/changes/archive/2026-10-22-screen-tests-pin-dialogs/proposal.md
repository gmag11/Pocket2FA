# Proposal

## Why

`pin_settings_dialogs.dart` is 136 executable lines at 0% and owns the PIN
warning, new-PIN and current-factor dialogs used by the settings screen. These
are security-adjacent UI contracts: validation before a PIN is stored, explicit
warnings, and a safe cancel path.

The dialogs can be tested without real secure storage by avoiding the actual
`verifyPin` call; the keypad and storage integration remain for the PIN-lock
stage.

## What Changes

- Add widget tests for `showPinForgotWarningDialog`: accept/cancel results and
  content.
- Add widget tests for `showSetPinDialog`: invalid length, mismatch, valid PIN
  and cancel.
- Add widget tests for `showCurrentFactorDialog`: empty-PIN feedback, cancel and
  the no-biometrics state.
- Raise `.coverage-baseline` to the measured overall value after the stage.

No production code, dependencies or public behavior changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This is test-only work; the change declares `skip_specs: true`.

## Impact

- New test `test/widget/pin_settings_dialogs_test.dart`.
- Reuses `pumpApp` and `FakeSettingsStorage`; no new dependencies.
- `.coverage-baseline` rises from 59.95 to the measured value (expected around
  61-62%, not guaranteed).
- No `lib/` changes, so the release APK and Android install are unaffected.
- Real PIN/biometric verification and `pin_lock_screen.dart` remain for later
  stages.
