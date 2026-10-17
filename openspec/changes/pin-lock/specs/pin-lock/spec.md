# Spec Delta

## Purpose

Provide an optional numeric PIN lock for Pocket2FA as an alternative to biometric authentication, so the app can be locked on devices where biometrics are unavailable, unreliable, or not preferred, without weakening the existing protection of local data.

## ADDED Requirements

### Requirement: Optional PIN lock

The system SHALL provide an opt-in PIN lock that protects access to local data on app start. The PIN MAY be any number of digits from 4 to 8; its length is determined by what the user enters, with no separate length selector. When the PIN lock is not enabled, app behavior MUST be unchanged.

#### Scenario: PIN lock is off by default

- **WHEN** the app is installed or the user has never enabled the PIN lock
- **THEN** no PIN prompt is shown and the app behaves exactly as before

#### Scenario: Enabling the PIN lock

- **WHEN** the user enables the PIN lock and types, then confirms, the same PIN of 4 to 8 digits
- **THEN** the PIN lock becomes active with that PIN and its length, and the app requires it on the next start

#### Scenario: Rejecting an out-of-range PIN

- **WHEN** the user tries to set a PIN with fewer than 4 or more than 8 digits
- **THEN** the PIN is rejected and the user is asked to enter it again

### Requirement: PIN is never stored in cleartext

The system SHALL store only a salted, slow cryptographic hash of the PIN in the platform secure storage, and SHALL verify entered PINs with a constant-time comparison. The raw PIN MUST NOT be persisted anywhere.

#### Scenario: Enabling stores only derived material

- **WHEN** the user enables the PIN lock
- **THEN** a random salt, the derived hash and the iteration count are persisted in secure storage, and the raw PIN is not stored

#### Scenario: Verification re-derives the hash

- **WHEN** the user enters a PIN to unlock
- **THEN** the system derives the hash from the entered PIN and the stored salt and compares it to the stored hash in constant time

### Requirement: PIN unlock gate

When the PIN lock is enabled, the system SHALL present the PIN lock screen before exposing local data and SHALL release the local encryption key only after a correct PIN or a successful biometric verification.

#### Scenario: App starts locked

- **WHEN** the app starts with the PIN lock enabled
- **THEN** the PIN lock screen is shown and local data is not accessible until the PIN (or biometric) succeeds

#### Scenario: Correct PIN unlocks

- **WHEN** the user enters the correct PIN
- **THEN** the local encryption key is released and the normal app UI is shown

#### Scenario: Wrong PIN is denied

- **WHEN** the user enters an incorrect PIN
- **THEN** the app remains locked and an error is shown

### Requirement: PIN and biometric coexist

When both the PIN lock and biometric protection are enabled and biometrics are available, the system SHALL allow either factor to unlock the app. The lock screen SHALL prompt for biometrics first and SHALL offer a "Use PIN" action. If the biometric prompt fails or is cancelled, or the user activates "Use PIN", the system SHALL show the numeric keypad.

#### Scenario: Biometric is prompted first

- **WHEN** the lock screen is shown with both the PIN lock and biometric protection enabled and biometrics supported
- **THEN** the system prompts for biometric verification and shows a "Use PIN" action

#### Scenario: Falling back to the PIN keypad

- **WHEN** the biometric prompt fails or is cancelled, or the user activates "Use PIN"
- **THEN** the system shows the numeric keypad so the PIN can be entered

#### Scenario: Either factor unlocks

- **WHEN** either a successful biometric verification or the correct PIN is provided
- **THEN** the app unlocks

#### Scenario: PIN-only lock opens the keypad directly

- **WHEN** the lock screen is shown with only the PIN lock enabled (no biometric)
- **THEN** the numeric keypad is shown directly

### Requirement: Brute-force throttling

The system SHALL throttle repeated incorrect PIN attempts with a growing delay (temporary lockout) and SHALL reset the attempt counter after a successful unlock.

#### Scenario: Repeated failures are throttled

- **WHEN** the user enters an incorrect PIN several times in a row
- **THEN** the system imposes a growing delay before accepting the next attempt

#### Scenario: Countdown is shown

- **WHEN** the system is temporarily throttling PIN entry
- **THEN** the lock screen shows the remaining time before another attempt is allowed

#### Scenario: Counter resets on success

- **WHEN** the user enters the correct PIN
- **THEN** the failure counter and any throttle delay are reset

### Requirement: Changing or disabling the PIN requires verification

The system SHALL require verification of the current PIN (or biometric, if enabled) before changing the PIN or disabling the lock, and SHALL require a new PIN to be entered twice.

#### Scenario: Changing the PIN requires the current factor

- **WHEN** the user changes the PIN to a different value (which may also have a different length, 4–8)
- **THEN** the current PIN (or biometric) must be verified first

#### Scenario: Disabling the lock requires the current factor

- **WHEN** the user disables the PIN lock
- **THEN** the current PIN (or biometric) must be verified first

#### Scenario: New PIN is entered twice

- **WHEN** the user sets or changes the PIN
- **THEN** the new PIN must be entered and confirmed identically before it is accepted

### Requirement: User is warned before enabling the PIN lock

The system SHALL warn the user, before the PIN lock is enabled, that forgetting the PIN with no biometric fallback means the local data cannot be recovered.

#### Scenario: Warning shown before enabling

- **WHEN** the user turns on the PIN lock
- **THEN** a clear warning about the consequences of forgetting the PIN is shown before the PIN is set

### Requirement: Platform consistency

The PIN lock SHALL behave consistently on Android, iOS, Windows and Linux using the platform secure storage already in use, and SHALL NOT alter behavior for users who do not enable it.

#### Scenario: Consistent across platforms

- **WHEN** the PIN lock is enabled on any supported platform
- **THEN** unlocking works the same way using that platform's secure storage

#### Scenario: Existing users are unaffected

- **WHEN** an existing user has only biometric protection enabled, or no lock at all
- **THEN** their experience and stored data are unchanged by this feature
