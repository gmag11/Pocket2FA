# Design

## Context

See `proposal.md` - Why. The file exposes three `show...Dialog` functions and
two private stateful dialogs. `showSetPinDialog` uses `isValidPin` and compares
the two controllers; `showCurrentFactorDialog` can verify a PIN through
`SettingsStorage` or biometrics through `SettingsService`.

## Goals / Non-Goals

**Goals:**

- Cover warning accept/cancel, new-PIN validation and current-factor empty input.
- Cover the no-biometrics variant.
- Keep tests independent of secure storage and local auth.

**Non-Goals:**

- Successful `storage.verifyPin` or biometric prompts (PIN-lock stage).
- Real PIN storage or unlock.
- Pixel-perfect dialog layout.

## Decisions

### Warning dialog

Open from a real button. Assert the title/content. Tap Cancel -> false; reopen
and tap Continue -> true. Pump after each dialog closes.

### New PIN dialog

Enter too-short PIN -> `pinInvalidLength`; enter a valid PIN with a different
confirmation -> `pinMismatch`; enter matching values -> the future returns the
PIN. Cancel -> null. Use `FilteringTextInputFormatter.digitsOnly`, so only
digits can be entered.

### Current factor dialog

Use a `SettingsService` backed by `FakeSettingsStorage`; biometrics remain
disabled, so the "Use biometrics" action is absent. Tap Verify with an empty
field and assert `pinIncorrect`. Cancel -> null. Do not tap Verify with a
non-empty PIN: that would call the real `verifyPin`.

### Dialog harness

Pump a `Scaffold` with `Builder` buttons that call each function and store the
result. This gives the dialogs a Navigator route and a testable return value.

## Risks / Trade-offs

- **Secure storage** → never submit a non-empty current PIN.
- **Biometrics plugin** → use the default unsupported fake.
- **Digit-only fields** → enter digits, not arbitrary text.
- **Dialog result futures** → capture results from the button callback and pump
  until the dialog closes.
- **Localization** → assert English strings from `pumpApp`.

## Migration Plan

Not applicable: test-only change. Rollback is deleting the new test and
restoring the previous baseline.

## Open Questions

None that affect scope. Exact coverage will be measured after the test runs.
