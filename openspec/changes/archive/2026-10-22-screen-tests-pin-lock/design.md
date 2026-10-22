# Design

## Context

See `proposal.md` - Why. `PinLockScreen` reads `SettingsService` and its
`SettingsStorage`, renders a numeric keypad with dots, and either submits a PIN
through `unlockWithPin` or starts a biometric-first mode through
`attemptUnlock`. It also supports hardware-keyboard digits, backspace and Enter,
and a lockout countdown.

## Goals / Non-Goals

**Goals:**

- Cover keypad input, delete, submit and the unlock callback.
- Cover incorrect PIN and lockout countdown.
- Cover biometric-first success/failure and fallback.
- Cover hardware-keyboard input and a custom title.

**Non-Goals:**

- Real secure storage, Hive or local-auth plugins.
- PIN setup/change/disable flows (covered by the dialogs stage).
- Pixel-perfect layout.

## Decisions

### Test-only fake storage

Create `FakePinStorage extends FakeSettingsStorage` in the test, overriding
`unlockWithPin`, `attemptUnlock` and `pinLockoutRemaining`. It accepts a known
PIN and can return a lockout duration or biometric success/failure.

Build `SettingsService(storage: fake)`, reload it, and pass it to
`PinLockScreen`. For biometric mode, seed the fake box with
`biometric_protection_enabled: true` and set `biometricsSupported: true`.

### Keypad tests

Tap digit buttons by their text, assert the dots appear, tap Delete and assert
one dot disappears, enter four digits and tap Unlock. On success assert the
`onUnlocked` callback and that the screen is removed by the parent.

For a wrong PIN, assert `pinIncorrect` and that the entered dots are cleared.

### Lockout

Seed a three-second lockout. Assert `pinThrottled(3)`, pump one second and assert
the countdown decreases. Digit taps are disabled while locked out.

### Biometric mode

With biometrics enabled and supported, the post-frame callback starts
`attemptUnlock`. On success assert `onUnlocked`; on failure assert the keypad
appears (`pinEnter`) and the biometric prompt does not dead-end.

### Hardware keyboard and title

Use `tester.sendKeyEvent` for digits, backspace and Enter while the keypad has
focus. Assert the title passed through `title` appears in the app bar.

## Risks / Trade-offs

- **Secure storage** → override all storage methods used by the screen.
- **Biometric post-frame callback** → pump after the first frame and settle the
  async fake.
- **Countdown timers** → cancel by replacing the tree; use fake durations and
  pump explicitly.
- **Keyboard focus** → ensure the keypad request-focus frame has run before
  sending keys.
- **Real localization** → use `pumpApp`.
- **No real crypto/PIN verification** → the fake decides success.

## Migration Plan

Not applicable: test-only change. Rollback is deleting the new test and
restoring the previous baseline.

## Open Questions

None that affect scope. Exact coverage will be measured after the test runs.
