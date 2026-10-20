# Proposal

## Why

Pocket2FA currently offers a single way to protect access to local data: biometric authentication (see `lib/services/settings_storage.dart`). On devices without usable biometrics, with unreliable or unenrolled sensors, or for users who simply prefer not to use them, there is no way to lock the app. A 4- to 8-digit PIN is a familiar, deterministic alternative that behaves the same on Android, iOS and desktop. Requested in GitHub issue #17.

## What Changes

- Add an optional app PIN lock (4 to 8 digits, entered freely by the user — there is no separate length selector) that gates access to the encrypted local storage on startup, as an alternative to — and combinable with — biometric protection.
- Never persist the PIN in plaintext: store a per-install random salt and a slow hash (PBKDF2-HMAC-SHA256) in the platform secure storage, and compare in constant time. The local encryption key is released only after a successful PIN or biometric verification.
- Present a lock screen when the app starts locked: when biometric protection is also enabled, prompt for biometrics first and show a "Use PIN" action; a failed/cancelled biometric prompt or tapping "Use PIN" reveals the numeric keypad. When only the PIN is enabled, show the keypad directly.
- Throttle repeated wrong entries with a growing delay / temporary lockout.
- Add PIN settings to the Security section of Settings: enable/disable and set/change PIN (entered twice). The PIN length (4–8 digits) is simply the number of digits the user types — no explicit length selector — and a clear explanation that a forgotten PIN with no biometric fallback means losing access to local data.
- Keep the existing biometric flow and the encrypted Hive storage unchanged; PIN is an additional gate, not a replacement for the key storage.
- Localize all new strings (en/es/fr).

## Capabilities

### New Capabilities
- `pin-lock`: An optional numeric PIN that locks the app on startup, verified against a salted hash in secure storage, with any length from 4 to 8 digits (taken from what the user enters), biometric as an alternative unlock path, and brute-force throttling.

### Modified Capabilities
<!-- None. The existing local-storage encryption and biometric behavior are unchanged; `pin-lock` layers on top of them. -->

## Impact

- **Affected code:** `lib/services/settings_storage.dart` (PIN hash storage/verification and unlock gate), `lib/services/settings_service.dart` (`pinEnabled`/`pinLength` plus setters), `lib/screens/settings_screen.dart` (setting tile + set/change PIN dialogs), a new lock screen (e.g. `lib/screens/pin_lock_screen.dart`), and the locked-state UI in `lib/screens/home_screen.dart` / `lib/screens/accounts_screen.dart` to route to it. New l10n keys in `lib/l10n/app_en.arb`, `app_es.arb`, `app_fr.arb` (and the generated translations).
- **Dependencies:** PIN hashing can be built with the already-present `crypto` package (HMAC-SHA256 plus a small PBKDF2 implementation); optionally add `pointycastle`/`cryptography` if a maintained PBKDF2 is preferred. No other new dependencies.
- **Storage:** new secure-storage entries (`pin_hash`, `pin_salt`, `pin_iterations`, `pin_length`) alongside the existing Hive master key and biometric flag. No Hive schema migration and no changes to existing data.
- **Platforms:** all (Android, iOS, Windows, Linux) — pure Dart plus the secure storage already in use.
- **Breaking changes / data-loss risk:** none for existing users (feature is opt-in, default off). A user who forgets the PIN with no biometric fallback cannot unlock local data; this is surfaced in the UI before enabling.
