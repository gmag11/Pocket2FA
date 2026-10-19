# Proposal

## Why

On Linux, when reading the platform secure storage fails for **any** reason, Pocket2FA
gets stuck showing *"Biometric authentication failed or was cancelled. Please retry to
unlock your local data."* The **Retry** button can never succeed there because
`local_auth` is not implemented on Linux (`MissingPluginException`), so the biometric
check always fails (`lib/screens/home_screen.dart:444`, `lib/services/settings_storage.dart`).
The message is also misleading: nothing biometric is involved when the failure is the
keyring (GitHub issue #20).

The *trigger* is an upstream plugin fragility that is already fixed: `flutter_secure_storage_linux`
3.0.1 calls `secret_service_get_sync(OPEN_SESSION | LOAD_COLLECTIONS)` during warm-up, so a
single broken item anywhere in the keyring — possibly owned by an unrelated app — makes the
whole read fail and the plugin reports `KeyringLocked`. `LOAD_COLLECTIONS` is removed in
`flutter_secure_storage_linux` 3.0.3. This change tracks the **app-side** hardening so a
recoverable storage error never becomes an unrecoverable dead end.

## What Changes

- Lock `flutter_secure_storage_linux` at **3.0.3** in `pubspec.lock` (the current constraint
  `flutter_secure_storage: ^10.3.1` already allows it) so the `LOAD_COLLECTIONS` trigger is gone.
- Model the locked state explicitly in `SettingsStorage`: distinguish *"waiting for biometric
  authentication"* from *"secure storage failed"*, and expose the last storage error.
- Make `attemptUnlock()` genuinely retry the storage path (re-read and open the box) instead of
  bailing out when biometrics are unavailable; a failure that happened at startup can now recover.
- Stop mapping storage errors to `biometricAuthFailed`: show the real keyring/storage error, and
  only offer a biometric Retry when biometric protection is enabled **and** supported.
- Record secure-storage failures through `LogService` so they are visible in the in-app debug log.
- Add the new localized strings in English, Spanish, and French (and regenerate the localization
  classes).

## Capabilities

### New Capabilities
- `secure-storage-unlock`: recoverable secure-storage failures and an honest, actionable locked
  screen that shows the real cause instead of a biometric dead end.

### Modified Capabilities
<!-- None: normal startup, biometric-protection opt-in, and stored data are unchanged. -->

## Impact

- **Affected code:** `lib/services/settings_storage.dart` (lock-state modelling + unlock retry),
  `lib/screens/home_screen.dart` (locked-screen messaging and Retry),
  `lib/l10n/app_{en,es,fr}.arb` and the generated `lib/l10n/app_localizations*.dart`,
  `pubspec.lock` (transitive plugin bump).
- **No new dependencies**, no dependency overrides, no data/format migration, no breaking changes.
- **Not covered:** adopting `flutter_secure_storage` 4.0.0 (fixes the bogus `xdg:schema` storage
  and migrates legacy items). It is a prerelease and writes to the keyring, so it must be
  validated on a branch first — tracked separately (see #1181).
