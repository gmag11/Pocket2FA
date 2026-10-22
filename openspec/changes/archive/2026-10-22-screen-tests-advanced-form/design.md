# Design

## Context

See `proposal.md` - Why. `AdvancedFormScreen` is a stateful `Form` with text
controllers for service, account, secret, period and counter, plus OTP-type,
digits, algorithm and group selectors. It builds an `AccountEntry` locally when
`serverHost` is empty and pops with the result.

The screen has create mode and edit mode. Edit mode prefills values, locks the
secret until explicitly unlocked, and a borrowed entry triggers a post-frame
pop.

## Goals / Non-Goals

**Goals:**

- Cover create/edit rendering, validation and type-dependent fields.
- Cover local submission and the route result.
- Cover the borrowed-entry redirect and duplicate-submit guard.

**Non-Goals:**

- Successful server upload (shared API harness later).
- Certificate or transport errors.
- Pixel-perfect layout or the exact advanced-panel animation.

## Decisions

### Tall surface and scrolling

Use `tester.view.physicalSize = const Size(800, 1400)` so most of the form is
built. If a target is off-screen, use `scrollUntilVisible` rather than tapping
by coordinates.

### Field order and labels

Use the visible labels to locate fields (`Name`, `Account`, `Secret`, etc.)
instead of relying only on `TextField` indices. Where a label is shared with a
button, scope with `find.descendant`.

### Validation

Submit an empty create form and assert the localized required-field messages.
Then fill a valid TOTP form and assert validation passes. Keep the secret value
valid Base32 so the shared entry-creation validation accepts it.

### OTP type switching

Tap TOTP, HOTP and STEAM and assert the period field for TOTP/Steam and the
counter field for HOTP. In edit mode the type buttons are disabled; assert that.

### Edit mode

Pass `existingEntry` with a group, TOTP options and a secret. Assert prefilled
text and that the secret starts locked; use the unlock action if present. A
borrowed entry must pop automatically after the first frame; test it through a
route harness.

### Local submission

Pump a route harness that pushes the form and stores the popped result. Fill
valid values with `serverHost: ''`, tap Create and assert the result is an
`AccountEntry` with the expected fields and that the route popped.

### Duplicate-submit guard

Once submission starts and the route is about to pop, tapping again must not
produce a second result. Assert the callback count stays one; the exact busy
indicator is not important.

## Risks / Trade-offs

- **Large scrollable form** → tall surface plus `scrollUntilVisible`.
- **Validator messages** → assert localized text found after submit, not
  internal validator state.
- **Secret validation** → use a known Base32 secret.
- **Type-dependent fields** → assert both presence and absence.
- **Borrowed redirect** → use a real route harness so `maybePop` has a route.
- **Server upload** → keep `serverHost` empty and defer the API case.

## Migration Plan

Not applicable: test-only change. Rollback is deleting the new test and
restoring the previous baseline.

## Open Questions

None that affect scope. Exact coverage will be measured after the test runs.
