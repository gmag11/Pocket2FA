# Design

## Context

See `proposal.md` — Why. Current state relevant to this change:

- `SettingsStorage.init()` (`lib/services/settings_storage.dart`) reads `hive_master_key` from `flutter_secure_storage` and opens the encrypted Hive box. When biometric protection is enabled, the stored `biometric_protection_flag` makes it prompt `local_auth` before reading the key; on failure it leaves `_unlocked = false` and the app shows an unlock/retry UI.
- The biometric implementation is a *gate*: it prompts via `local_auth`, then reads the same key. The key itself is not cryptographically bound to biometrics; it is protected by the OS keystore / secure storage.
- Locked-state UI already exists in `lib/screens/home_screen.dart` (retry button) and `lib/screens/accounts_screen.dart` (unlock button), both calling `storage.attemptUnlock()`.
- Settings live in the encrypted Hive box (`SettingsService`), with a `biometric_protection_enabled` key; settings are loaded only once the box is unlocked.

## Goals / Non-Goals

**Goals**
- Optional PIN of 4 to 8 digits that locks the app on startup; the length is whatever the user types — no separate length selector.
- PIN stored only as a salted, slow hash, verified in constant time.
- Coexists with biometrics: either factor unlocks when both are enabled.
- Brute-force resistance through throttling after repeated failures.
- Consistent behavior on Android, iOS and desktop; no change for users who don't enable it.

**Non-Goals**
- Replacing the OS keychain/keystore or changing how the Hive master key is stored.
- Auto-wipe / factory reset after N failed attempts (too destructive; explicit user action only).
- Lock-on-background after a timeout, per-account PINs, or alphanumeric passphrases — possible future work.
- A "forgot PIN" recovery that bypasses verification (there is none, by design).

## Decisions

### 1. PIN is an additional unlock factor, not a replacement for the Hive key

Keep `hive_master_key` in `flutter_secure_storage` and treat the PIN as a gate that must be satisfied before the key is read, mirroring how biometrics work today. `attemptUnlock()` gains a PIN path.

**Rationale:** avoids re-encrypting/rewriting existing users' data and keeps a single, proven code path for opening the box. A stronger design would wrap the Hive key with a PIN-derived key (so a wrong PIN cannot decrypt even with secure-storage access), but that changes data-at-rest handling and makes a forgotten PIN catastrophic with no recovery. Out of scope here; note as future hardening.

**Alternative considered:** derive the Hive key from the PIN via PBKDF2. Rejected for now (larger blast radius, no recovery, diverges from the biometric model).

### 2. Store a salted PBKDF2 hash, never the PIN

On enable, generate a cryptographically-random 16-byte salt, derive `hash = PBKDF2-HMAC-SHA256(pin, salt, iterations)` with a moderate iteration count (target ~200–250 ms on a mid device), and store `pin_salt`, `pin_hash` (base64), `pin_iterations` and `pin_length` (the digit count of the chosen PIN, 4–8) in `flutter_secure_storage`. Verification re-derives and compares with a constant-time equality check.

**Rationale:** even the shortest allowed PIN (4 digits) has only 10k possibilities, so a plain digest is trivially brute-forced; the salt defeats precomputation and the iteration count makes each guess costly. The 4-digit minimum is a usability floor, not a security recommendation — longer PINs (up to 8 digits, i.e. 100M combinations) are strictly stronger. `crypto` (already a dependency) provides `Hmac`/`sha256`; implement PBKDF2 directly or add a maintained implementation.

### 3. Lock screen: biometric-first with a "Use PIN" fallback

Add `lib/screens/pin_lock_screen.dart` with two states:

- **Biometric-first** (default when biometric protection is also enabled): on showing the lock screen, promptly trigger the `local_auth` prompt and display a "Use PIN" action. If the biometric prompt fails or is cancelled, or the user taps "Use PIN", switch to the keypad state.
- **Keypad**: dots for the stored PIN length, a 0–9 keypad with delete, error feedback on wrong entry, and automatic submit once the expected number of digits is entered.

When only the PIN is enabled (no biometric), the lock screen opens directly in the keypad state.

**Rationale:** mirrors how OS lock screens behave — try the fastest factor (biometrics) first, keep the deterministic one (PIN) one tap away. Starting the biometric prompt proactively means a user with working biometrics never needs to see the keypad, while a biometric failure never dead-ends. Auto-submit avoids an extra tap and matches common PIN UX.

### 4. PIN material lives in secure storage; no length selector

All PIN material — `pin_hash`, `pin_salt`, `pin_iterations` and `pin_length` — is owned by `SettingsStorage` in secure storage, which is readable before the Hive box is unlocked (same as `biometric_protection_flag`). The PIN lock is "enabled" iff `pin_hash` is present (`hasPin()`), so no separate `pin_enabled` flag is required and a missing hash can never leave the app permanently locked. `pin_length` is the digit count of the PIN the user typed (4–8); it is used only to render the correct number of dots and to know when to auto-submit on the lock screen. `SettingsService` exposes these as read-only state (`pinEnabled`, `pinLength`) for the settings UI.

There is **no length selector**: the user simply types a PIN and its number of digits is the length. Setting or changing a PIN takes the typed value, validates it is 4–8 digits, and stores the derived material.

**Rationale:** the length is not really an independent choice — it is a property of the secret the user chose, so a separate selector is redundant and adds UI. Keeping the material in secure storage (rather than the settings box) is required because the lock screen must know `pin_length` and verify the PIN *before* the encrypted box — and therefore `SettingsService`'s box-backed settings — is available.

### 5. Attempt throttling

Track consecutive failed attempts in memory (reset on success or app restart) and apply a growing delay before accepting the next entry (e.g. after 5 wrong: 30 s, then doubling up to a cap), showing a countdown on the lock screen.

**Rationale:** discourages shoulder-surfing/brute-force attempts at the UI without a destructive wipe.

### 6. Changing or disabling the PIN requires the current factor

Changing the PIN (to a different value, which may also change its length) or disabling the lock requires verifying the current PIN (or biometric, if enabled). Enabling a PIN requires entering it twice.

**Rationale:** prevents a passing bystander from weakening the lock.

## Risks / Trade-offs

- **[Medium] Forgotten PIN with no biometric fallback locks the user out of local data.** → Clearly warn in the UI before enabling; no bypass is stored. Biometric remains an optional recovery path.
- **[Low] A 4-digit PIN is the weakest permitted option (10k combinations).** → Rely on throttling plus the slow hash, and let users type up to 8 digits (100M combinations) when they want a stronger PIN.
- **[Low] PBKDF2 iteration choice trades startup latency for resistance.** → Tune to ~200–250 ms and persist the iteration count so it can be raised later on existing installs.
- **[Low] `crypto` has no PBKDF2 helper.** → Implement it (small, well-specified) or add `pointycastle`; both are non-breaking.
- **[Low] Concurrent biometric and PIN prompts.** → Route both through the single lock screen / `attemptUnlock()` so only one is active at a time.
- **[Low] Desktop secure-storage quirks.** → Reuse the existing `flutter_secure_storage` setup already used on Windows/Linux; no platform-specific code.

## Open Questions

- Should there be an optional "lock after N minutes in background" in addition to lock-on-start? (Proposed: no, out of scope.)
- Should N failed attempts force biometric-only until restart? (Proposed: no; just backoff.)
