# Proposal

## Why

In the manual account form (`AdvancedFormScreen`), pressing **Create** starts an asynchronous
server call but leaves the button enabled, so the form gives no feedback that anything is
happening. A second press starts a second creation request; because the form returns a
separate local entry for each press, the same HOTP (or TOTP/Steam) account is created and
stored multiple times. The same handler also serves **Update**, so editing has the same
double-submit exposure.

## What Changes

- Make the form's submit action single-flight: while a create or update request is in flight,
  further presses must be ignored, not start another request.
- Show a clear in-flight state on the action button (disabled label with a progress indicator)
  instead of leaving an apparently idle button.
- Disable the Cancel action and block back navigation while submitting, so the in-flight
  operation cannot complete and pop a route the user has already left.
- Re-enable the actions and show an error/keep the form open if submission fails before the
  form is popped; on success the form pops exactly once.
- Keep local validation as the first step: invalid forms do not enter the in-flight state.

## Capabilities

### New Capabilities

- `account-form-submission`: how the manual create/edit form handles submission — one request
  per user action, visible in-flight feedback, and deterministic navigation on completion.

### Modified Capabilities

<!-- None: account persistence, OTP semantics, server API and offline retry behavior are unchanged. -->

## Impact

- **Affected code:** `lib/screens/advanced_form_screen.dart` (submit handler and bottom action
  bar). No changes expected in `entry_creation_service.dart`, `api_service.dart`, or the
  account list/home screen callers.
- **No API, dependency, data-migration or localization changes**; the in-flight label can reuse
  the existing create/update strings.
- **Not covered:** the form currently ignores the HOTP counter field and always sends a counter
  of 0 when creating an account (`advanced_form_screen.dart:603-618` passes `_periodCtrl`, not
  `_counterCtrl`). That is a separate creation-correctness defect and is left out of this change.
