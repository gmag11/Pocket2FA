# Design

## Context

`AdvancedFormScreen` is a single `StatefulWidget` used for both create and edit. Its bottom bar
contains an `ElevatedButton` whose `onPressed` runs the entire validation, local-entry build,
server request and navigation inline (`lib/screens/advanced_form_screen.dart:509-673`). Nothing
records that the handler is running, so the button stays tappable and each tap starts an
independent request and builds an independent `AccountEntry`.

The create path already tolerates server failure: `EntryCreationService.createEntryOnServer`
returns the local entry (or the caller falls back to it), and the form pops it so the home screen
can persist it and retry upload later. This change must preserve that offline-first behavior.

## Goals / Non-Goals

**Goals:**

- Exactly one in-flight submission per screen instance, regardless of how often the button is
  pressed.
- Visible busy state and blocked exit while the request is pending.
- One navigation when submission completes, with the same account object the current code
  returns.
- A path that re-enables the form if submission ends without a result.

**Non-Goals:**

- Changing server payloads, OTP parameters, offline retry, or account persistence.
- Adding a global request deduplication layer in `ApiService`; the form is the only source of
  repeated user-triggered create calls.
- Fixing the ignored HOTP counter field (documented in the proposal).

## Decisions

### Track submission in local widget state

Add `bool _isSubmitting = false` to `_AdvancedFormScreenState`. The submit handler becomes an
early-return guard: `if (_isSubmitting) return;`, then validate, then
`setState(() => _isSubmitting = true)` before the first `await`. A guard flag is preferred over a
timer/debounce because the problem is a slow server response, not accidental double-taps within a
few milliseconds; a timer would still allow a second request after the debounce window while the
first one is pending.

Alternatives considered: disabling the button by rebuilding from an external state container
(overkill for one widget), and relying on `showDialog` barriers (changes the visible UX and is not
needed).

### Extract a single submit method

Move the handler body into `Future<void> _submit()`. This keeps `build()` readable, gives the
guard a single place, and lets the create and edit branches converge on one `navigator.pop(result)`
instead of popping from three separate spots. Existing log lines and payload construction remain
unchanged.

### Busy rendering and blocked exit

- Submit button: `onPressed: _isSubmitting ? null : _submit`. While busy, its child is a small
  `CircularProgressIndicator` (fixed size, white) instead of the Create/Update label, and the
  disabled background color stays close to the enabled brand color so the spinner remains visible.
- Cancel button: `onPressed: _isSubmitting ? null : () => Navigator.of(context).pop()`.
- Wrap the `Scaffold` in `PopScope(canPop: !_isSubmitting)` so the system back gesture cannot
  remove the route mid-request. Requests are bounded by `ApiService`'s connect/receive timeouts
  (10 s / 20 s), so the block is temporary.

Blocking exit, rather than allowing it and guarding the pop with `mounted`, is chosen because a
captured `NavigatorState` can still pop the underlying route after the form is gone; preventing
the exit avoids that class of bug entirely. A `mounted` check before `pop` remains as a defensive
guard.

### Reset on unexpected failure

Wrap the submit body in `try/finally`. On success the route is popped and the state is discarded;
in `finally`, call `setState(() => _isSubmitting = false)` only when `mounted` and the route was
not popped. Track completion with a local `bool popped = false` (set immediately before
`navigator.pop(result)`) so an unexpected exception keeps the form usable instead of leaving the
button disabled forever.

## Risks / Trade-offs

- **Long server hang blocks Cancel/back** → requests are bounded by the API timeouts, and the
  busy indicator explains the wait. If timeouts prove too long in practice, they can be tuned
  independently in `ApiService`.
- **User believes the app froze** → the spinner replaces the label and the button visibly loses
  its active look.
- **Double navigation still possible from an unexpected code path** → all success branches funnel
  through one `pop`, and the `popped` flag prevents a second pop after completion.
- **`setState` after dispose** → guarded by `mounted`; `PopScope` plus the disabled Cancel reduce
  the window to a parent-initiated route removal.
