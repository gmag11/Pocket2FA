# secure-storage-unlock Specification

## Purpose
Ensure a failure to read the platform secure storage (for example, a broken GNOME keyring item
on Linux) never leaves Pocket2FA stuck on a misleading biometric screen with a Retry that cannot
succeed. A storage failure must be reported honestly, must remain retryable, and the upstream
trigger must be removed.

## Requirements

### Requirement: Secure-storage failures are retryable, not a dead end

When opening the local encrypted storage fails because the platform secure storage cannot be
read, the system SHALL keep the storage locked but MUST allow a subsequent retry to re-run the
secure-storage read and open the box. A retry MUST be able to succeed on a later attempt if the
underlying read succeeds, even when biometric authentication is not available on the platform.

#### Scenario: Startup storage failure recovers on retry

- **WHEN** the secure-storage read fails during startup and the user presses Retry after the cause is gone
- **THEN** the app re-reads the secure storage, opens the encrypted box, and unlocks

#### Scenario: Retry does not depend on biometric support

- **WHEN** biometric protection is not enabled and the platform has no biometric implementation
- **THEN** a retry still opens the box instead of returning failure merely because biometrics are unavailable

### Requirement: The locked screen reports the real cause

The locked screen SHALL distinguish a secure-storage/keyring failure from a pending biometric
authentication, and MUST NOT describe a storage failure as a biometric authentication failure.
When the secure storage cannot be read, the screen SHALL present a storage/keyring-specific
message together with the underlying error detail.

#### Scenario: Storage failure is not labelled biometric

- **WHEN** the secure-storage read fails and the box is locked
- **THEN** the screen shows a storage/keyring error message, not "Biometric authentication failed"

#### Scenario: Details are visible

- **WHEN** the secure-storage read fails
- **THEN** the screen exposes the underlying error text so the user can diagnose the keyring problem

### Requirement: No biometric Retry where biometrics cannot work

When biometric protection is not enabled, or the platform does not support biometrics, the
system SHALL NOT present a biometric-authentication retry that can never succeed. It SHALL show
the applicable cause (storage error, or biometrics unavailable).

#### Scenario: Linux without biometric support

- **WHEN** the app runs on a platform without a biometric implementation and the storage is locked
- **THEN** no biometric-failure message is shown and no biometric Retry is offered

#### Scenario: Biometric lock without support

- **WHEN** a biometric lock is pending but biometrics are unavailable on the current platform
- **THEN** the screen reports that biometrics are not available

### Requirement: Secure-storage failures are recorded

A failure to read the platform secure storage SHALL be recorded through the application's log
service so it can be inspected and exported from the in-app debug log.

#### Scenario: Failure appears in the debug log

- **WHEN** the secure-storage read fails
- **THEN** an entry describing the failure is written to the debug log

#### Scenario: Failure is recorded even when the logging preference is unreadable

- **WHEN** the secure-storage read fails and the debug-logging preference cannot be read because
  it is stored in that same secure storage
- **THEN** log capture is enabled for the session so the failure is written to the debug log

### Requirement: Remove the upstream keyring-enumeration trigger

The build SHALL use a `flutter_secure_storage_linux` version that does not enumerate all keyring
collections during warm-up, so a single unrelated broken keyring item cannot make the app's own
secure-storage reads fail.

#### Scenario: Broken unrelated keyring item does not block startup

- **WHEN** the OS keyring contains a broken item that belongs to another application
- **THEN** the app's own secure-storage read succeeds and the app starts without a lock screen

### Requirement: Existing behavior is preserved

The change SHALL NOT alter normal startup, the biometric-protection opt-in flow, or the stored
encrypted data. Platforms with working biometrics SHALL keep prompting and keep their current
Retry behavior.

#### Scenario: Healthy storage starts unlocked

- **WHEN** the secure storage can be read and the box opens normally
- **THEN** the app starts unlocked exactly as before

#### Scenario: Android/Windows biometric protection unchanged

- **WHEN** biometric protection is enabled on a platform that supports it
- **THEN** the app still prompts for biometric authentication to unlock and still offers Retry on failure
