# Tasks

## 1. PIN storage & verification

- [x] 1.1 In `lib/services/settings_storage.dart`, add secure-storage keys `pin_hash`, `pin_salt`, `pin_iterations`, `pin_length`
- [x] 1.2 Implement PBKDF2-HMAC-SHA256 derivation (helper in `SettingsStorage` or a small `lib/services/pin_service.dart`) with a tunable iteration count
- [x] 1.3 Implement `setPin(String pin)`: validate the PIN is 4–8 digits, generate a random 16-byte salt, derive and persist the hash material (including `pin_length`)
- [x] 1.4 Implement `verifyPin(String pin)` with a constant-time comparison
- [x] 1.5 Implement `hasPin()` and `clearPin()` (disable)
- [x] 1.6 Extend the unlock flow so the Hive key is released when either the PIN or biometric verification succeeds

## 2. Settings model & service

- [x] 2.1 Expose `pinEnabled` and `pinLength` from `SettingsService` as read-only state derived from `SettingsStorage` (`hasPin()` / stored `pin_length`), plus `enablePin(pin)` / `changePin(current, new)` / `disablePin(current)`
- [x] 2.2 Derive `pinEnabled` from `hasPin()` so a missing hash cannot leave the app permanently locked

## 3. Lock screen UI

- [x] 3.1 Add `lib/screens/pin_lock_screen.dart` with two states: biometric-first and keypad
- [x] 3.2 Keypad state: one dot per digit typed (never the stored length), numeric keypad, delete, error feedback and an explicit Unlock button (no auto-submit)
- [x] 3.3 Biometric-first state: when biometric is also enabled, prompt for biometrics on show and offer a "Use PIN" action; fall back to the keypad on failure/cancel (including platform errors that would otherwise leave the screen stuck) or when "Use PIN" is tapped (and open the keypad directly when PIN-only)
- [x] 3.4 Show the throttle countdown after repeated failures
- [x] 3.5 Route `home_screen.dart` and `accounts_screen.dart` locked states to the PIN lock screen when PIN is enabled (biometric retry otherwise)
- [x] 3.6 Support hardware keyboard input on the lock screen on desktop (digits, backspace, Enter)

## 4. Settings UI

- [x] 4.1 Add a "PIN lock" tile to the Security section in `lib/screens/settings_screen.dart` (enable switch)
- [x] 4.2 Add a "Change PIN" entry (no length selector — the length simply follows the digits entered)
- [x] 4.3 Add set/change PIN dialogs requiring entry twice and verifying the current factor before changing/disabling
- [x] 4.4 Show the "forgotten PIN = lost data" warning before enabling

## 5. Localization

- [x] 5.1 Add new keys to `lib/l10n/app_en.arb`, `app_es.arb`, `app_fr.arb` (PIN lock, enter/confirm/change PIN, PIN incorrect, throttled, forgotten-PIN warning, use biometrics)
- [x] 5.2 Regenerate localizations (`flutter gen-l10n`)

## 6. Verification

- [x] 6.1 `flutter analyze` passes with no new issues
- [x] 6.2 Enable a 4-digit PIN, restart: the lock screen appears and the correct PIN unlocks
- [x] 6.3 Same for an 8-digit PIN (and an intermediate length, e.g. 6)
- [x] 6.4 Wrong PINs trigger the throttle countdown; the correct PIN after the delay unlocks
- [x] 6.5 With biometric + PIN both enabled, biometric unlocks without the PIN
- [x] 6.6 Disabling PIN requires the current PIN and restores the previous (unlocked / biometric) behavior
- [x] 6.7 Existing users with only biometric or no lock are unaffected; no data migration
- [x] 6.8 Verify on Android, iOS (if available) and desktop (Windows/Linux) secure-storage backends
