# Proposal

## Why

`AdvancedFormScreen` is 323 executable lines at 0% and is the largest remaining
self-contained form. It handles manual entry creation and editing: service,
account, secret, group, OTP type, digits, algorithm, period/counter, validation,
local entry construction and optional server upload.

Covering it now addresses the largest UI gap before the home screen itself.

## What Changes

- Add widget tests for `AdvancedFormScreen`:
  - create-mode rendering and field entry;
  - required-field and secret validation;
  - TOTP/HOTP/Steam type switching and the corresponding period/counter fields;
  - advanced digits/algorithm controls;
  - group selection;
  - edit-mode prefill and the borrowed-account redirect;
  - local submission with an empty server host and route pop;
  - duplicate-submit guarding.
- Raise `.coverage-baseline` to the measured overall value after the stage.

No production code, dependencies or public behavior changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This is test-only work; the change declares `skip_specs: true`.

## Impact

- New test `test/widget/advanced_form_screen_test.dart`.
- Reuses `pumpApp`, `AccountEntry`, `GroupEntry` and the existing form helpers;
  no new dependencies.
- `.coverage-baseline` rises from 55.03 to the measured value (expected around
  59-61%, not guaranteed).
- No `lib/` changes, so the release APK and Android install are unaffected.
- Successful server upload is deferred until a dedicated API-harness stage; the
  local construction and validation paths are covered here.
