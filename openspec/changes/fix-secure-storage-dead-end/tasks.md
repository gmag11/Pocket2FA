# Tasks

## 1. Dependency: remove the upstream trigger

- [x] 1.1 Bump the locked `flutter_secure_storage_linux` to `3.0.3` in `pubspec.lock`
      (constraint `^3.0.1` already allows it; no `pubspec.yaml` change, no overrides)
- [x] 1.2 Confirm `flutter pub get`/CI still resolves and no unrelated packages change

## 2. Storage: model the locked state honestly

- [x] 2.1 In `lib/services/settings_storage.dart`, add `isBiometricLocked` and a nullable
      `storageError` (with `hasStorageError`) alongside `isUnlocked`
- [x] 2.2 Split the storage read/open work into a private helper reusable by `init()` and
      `attemptUnlock()`; set `isBiometricLocked = true` (not an error) when a prompt is pending
      and `storageError` when the secure-storage read throws
- [x] 2.3 Route a caught `local_auth` `MissingPluginException` to "biometrics unsupported"
      instead of treating it as a storage failure
- [x] 2.4 Make `attemptUnlock()` retry the storage path: read the biometric flag, prompt only
      if protection is enabled and supported, then open the box — so a startup failure recovers
- [x] 2.5 Log storage failures via `LogService.error` so they appear in the debug log viewer
- [ ] 2.6 Force log capture on when the secure-storage read fails, so the failure is recorded
      even though the debug-logging preference lives in the storage that just failed

## 3. UI: honest locked screen

- [x] 3.1 In `lib/screens/home_screen.dart`, choose the locked-screen message from state:
      real storage error when `hasStorageError`, `biometricsNotAvailable` when a biometric lock
      is pending but unsupported, otherwise the biometric message
- [x] 3.2 Show the underlying storage error text (so users can act on the keyring problem) and
      keep the Retry button pointing at `attemptUnlock()`
- [x] 3.3 On a failed Retry, surface the matching message instead of a generic
      `authenticationFailed` SnackBar

## 4. Localization

- [x] 4.1 Add the new storage-error strings to `app_en.arb`, `app_es.arb`, `app_fr.arb`
- [x] 4.2 Regenerate `lib/l10n/app_localizations*.dart` (`flutter gen-l10n`)

## 5. Verification

- [x] 5.1 `flutter analyze` passes with no new issues for the modified `lib/` files
- [x] 5.2 On Linux with a healthy keyring: the app starts unlocked as before (no lock screen)
- [x] 5.3 On Linux with a broken keyring item: the app shows the real storage/keyring error
      (not "biometric authentication failed") and logs it
- [x] 5.4 After the `3.0.1` → `3.0.3` bump and with the same keyring, the app starts and the
      existing data/encryption key are read normally (accepted risk: not verified, user decision)
- [ ] 5.5 Android/Windows with biometric protection enabled: the biometric prompt and Retry
      behavior are unchanged
