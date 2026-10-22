# Proposal

## Why

`settings_storage.dart` is the largest remaining service gap: 185 of 221
executable lines uncovered (16.3%). It owns the encrypted Hive box, the platform
keyring key, PIN hashing/verification, lockout throttling and biometric release.
The pure crypto helpers are already tested; the class lifecycle is not.

## What Changes

- Add tests for the `SettingsStorage` class with fake secure-storage,
  local-auth and path-provider platforms:
  - fresh init, key creation and encrypted box opening;
  - locked, storage-error and retry paths;
  - PIN set/verify/change/clear and throttling;
  - biometric flag enable/disable and key release;
  - readable/writable settings box and `readKey`.
- Raise `.coverage-baseline` to the measured overall value after the stage; if
  coverage reaches 70.0, it stays pinned there.

No production code, dependencies or public behavior changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This is test-only work; the change declares `skip_specs: true`.

## Impact

- New test `test/unit/services/settings_storage_test.dart` plus test-only fake
  platform implementations.
- May add direct test dependencies already present transitively
  (`flutter_secure_storage_platform_interface`,
  `local_auth_platform_interface`) if required for fakes.
- `.coverage-baseline` rises from 68.65 to the measured value (expected 70-72%;
  the 70.0 target pins there).
- No `lib/` changes, so the release APK and Android install are unaffected.
- The home screen and remaining UI gaps stay for later stages.
