# Proposal

## Why

`pin_lock_screen.dart` is 190 executable lines at 0% and is the security entry
point shown before the app unlocks. It owns the numeric keypad, PIN submission,
lockout countdown, hardware-keyboard input and the biometric-first fallback.

The PIN dialogs and settings storage primitives are already partially covered.
A fake storage subclass can exercise this screen without secure storage or the
local-auth plugin.

## What Changes

- Add widget tests for `PinLockScreen`:
  - keypad digit entry, delete and submit enablement;
  - successful unlock and the `onUnlocked` callback;
  - incorrect PIN feedback and lockout countdown;
  - biometric-first success and failure fallback to the keypad;
  - hardware-keyboard digits, backspace and Enter;
  - custom title rendering.
- Raise `.coverage-baseline` to the measured overall value after the stage.

No production code, dependencies or public behavior changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This is test-only work; the change declares `skip_specs: true`.

## Impact

- New test `test/widget/pin_lock_screen_test.dart`.
- Adds a test-only fake storage subclass overriding PIN/lockout/biometric
  methods; no new dependencies.
- `.coverage-baseline` rises from 63.11 to the measured value (expected around
  66-68%, not guaranteed).
- No `lib/` changes, so the release APK and Android install are unaffected.
- Real secure storage/local-auth behavior remains outside this stage.
