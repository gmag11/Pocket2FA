# Proposal

## Why

`OtpService` is at 57.5% and `LogService` at 37.0%. The uncovered OTP paths
include MD5, Steam codes, unsupported types and secret normalization; the
uncovered log paths include level formatting, the 1000-entry cap, notification
and file export. A broken OTP path locks users out, and a broken export makes
diagnostics useless exactly when they are needed.

Both are pure Dart and fast to test; no network or device is involved.

## What Changes

- Extend `test/unit/services/otp_service_test.dart` with:
  - unsupported/HOTP types returning an empty code;
  - Base32 secrets with spaces and padding;
  - `base32Decode` and `pow10` edge cases;
  - the MD5 algorithm path;
  - the Steam TOTP path, both through `generateOtp` and directly, including
    empty/invalid secrets, charset, determinism and time sensitivity.
- Extend `test/unit/services/log_service_test.dart` with:
  - level tags and `LogEntry.toString`;
  - the four convenience shortcuts;
  - the 1000-entry cap and the delayed `entryCount` notification;
  - `exportAsText` with a fixed clock and captured entries;
  - `exportToFile` success and failure with a mocked `path_provider` channel.
- Remove unreachable code from `OtpService`: the hex/UTF-8 fallback in
  `_decodeSecret` (Base32 decoding never throws), the unused `_hotp` stub, and
  the commented-out HOTP persistence helpers.
- Raise `.coverage-baseline` to the measured overall value (expected around
  48%).

The only production change is the removal of unreachable code; OTP behavior is
unchanged.

## Capabilities

### New Capabilities

None. This change only adds tests, so it declares `skip_specs: true`.

### Modified Capabilities

None.

## Impact

- Two existing test files under `test/unit/services/`.
- `lib/services/otp_service.dart`: deletion of unreachable code only.
- `.coverage-baseline` updated.
- No changes to `pubspec.yaml` or CI workflows.
