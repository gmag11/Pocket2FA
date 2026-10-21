# Tasks

## 1. Single-flight submit flow

- [x] 1.1 Add `_isSubmitting` and a local `popped` completion flag to `_AdvancedFormScreenState`, and extract the inline `onPressed` body into `Future<void> _submit()` that returns early when `_isSubmitting` is true or validation fails; verify with `flutter analyze` and by reading that validation runs before the flag is set
- [x] 1.2 Set `_isSubmitting` only after successful validation, just before the first `await`, and wrap the submit body in `try/finally` that re-enables the form when the route was not popped; verify with `flutter analyze` and that an unexpected error leaves the Create/Update button enabled
- [x] 1.3 Funnel the create and edit branches through one `navigator.pop(result)` guarded by `mounted` and the `popped` flag, setting `popped = true` immediately before the pop; verify by inspection that no success branch pops twice and `flutter analyze` passes

## 2. In-flight UI and exit blocking

- [x] 2.1 Disable the submit button while `_isSubmitting` and replace its Create/Update label with a fixed-size white `CircularProgressIndicator`, keeping the disabled background close to the brand color so the spinner remains visible; verify in a debug run that the button visibly changes on press
- [x] 2.2 Disable the Cancel button while `_isSubmitting` and wrap the `Scaffold` in `PopScope(canPop: !_isSubmitting)`; verify with `flutter analyze` and that back navigation does not dismiss the form during a pending request

## 3. Verification

- [x] 3.1 Run `flutter analyze` and confirm no new warnings or errors
- [x] 3.2 Build the release variant with `flutter build apk --release --split-per-abi` and confirm it compiles; do not install it on the device without asking
- [x] 3.3 With a HOTP account form pointed at a slow or unreachable server, press Create twice in quick succession and confirm only one account is created and the form closes once

## Workflow follow-up

- Archive the change after the project's review requirements are satisfied.
- Verify the archived result.
