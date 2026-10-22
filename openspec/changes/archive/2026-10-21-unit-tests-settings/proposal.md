# Proposal

## Why

`SettingsService` is 184 lines with 133 uncovered, and it decides startup
defaults, theme migration, debug logging, auto-sync, and the PIN/biometric
guards. A regression here does not crash: it silently resets a user's settings,
disables logging, or weakens a security check.

The pure helpers in `settings_storage.dart` that protect the PIN are also
untested (`isValidPin`, PBKDF2 derivation, constant-time comparison). They are
cheap to test and security-sensitive.

## What Changes

- Add `test/unit/services/settings_service_test.dart` covering:
  - loading persisted values from unlocked storage, including stored theme and
    the legacy `dark_mode_enabled` migration;
  - the locked-storage path, including the storage-error case that force-enables
    debug logging;
  - the `SharedPreferences` fallback path and every setter, including
    notification and persistence;
  - the no-storage guards for PIN and biometric operations.
- Add `test/unit/services/settings_security_test.dart` covering PIN length and
  digit validation, PBKDF2-HMAC-SHA256 against a known vector, key length, salt
  sensitivity, and `constantTimeEquals`.
- Extend `FakeSettingsStorage` with an optional storage-error value so the
  locked-error path can be exercised without platform channels.
- Raise `.coverage-baseline` to the measured overall value (expected around
  42%).

No production changes and no plugin or network calls.

## Capabilities

### New Capabilities

None. This change only adds tests, so it declares `skip_specs: true`.

### Modified Capabilities

None.

## Impact

- New tests under `test/unit/services/`.
- Small test-only addition to `test/helpers/fakes/fake_settings_storage.dart`.
- `.coverage-baseline` updated.
- No changes to `lib/`, `pubspec.yaml`, or CI workflows.
