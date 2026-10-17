# Spec Delta

## Purpose

Guarantee that the parameters of an account (whether received from the server or entered locally) can never make one-time-password generation throw and can never leave an account tile without a code and without a scheduled refresh.

## ADDED Requirements

### Requirement: OTP generation never divides by a non-positive period

The system SHALL treat a missing, zero or negative time period as the default period (30 seconds) when generating a time-based code, and SHALL never perform a division that can fail because of the period value.

#### Scenario: Account with a zero period

- **WHEN** an account's stored period is `0`
- **THEN** its code is generated using a 30-second period instead of failing

#### Scenario: Account with a negative period

- **WHEN** an account's stored period is negative
- **THEN** its code is generated using a 30-second period instead of producing a nonsensical time step

#### Scenario: Scheduling uses the same effective period

- **WHEN** a code is generated with a substituted default period
- **THEN** the next refresh and the countdown animation use that same effective period

### Requirement: Digit count is bounded

The system SHALL bound the number of digits used for a code to a supported range, applying a documented default when the account's value is missing or outside it, and SHALL NOT perform work proportional to an unbounded digit count.

#### Scenario: Absurd digit count

- **WHEN** an account's digit count is missing, zero, negative or implausibly large
- **THEN** the code is generated with the documented default number of digits and the device does not hang or exhaust memory

#### Scenario: Supported digit count is honoured

- **WHEN** an account's digit count is within the supported range
- **THEN** the code is generated with exactly that many digits

### Requirement: Unknown algorithms and short digests cannot throw

The system SHALL fall back to the default algorithm when an account specifies an unsupported one, and SHALL perform dynamic truncation within the bounds of the digest actually produced, so that no algorithm (including the shortest digest the app accepts) can index outside it.

#### Scenario: Unsupported algorithm

- **WHEN** an account specifies an algorithm the app does not implement
- **THEN** the code is generated with the default algorithm instead of failing

#### Scenario: Short digest

- **WHEN** an account uses an algorithm whose digest is shorter than the offset used by dynamic truncation
- **THEN** truncation stays inside the digest and a code is produced without an out-of-range error

### Requirement: A failing generation still leaves the tile working

When generation fails or cannot be completed, the system SHALL NOT leave the tile frozen: it SHALL surface an unavailable indication for that account and SHALL keep a refresh scheduled so the tile recovers on its own.

#### Scenario: Generation throws

- **WHEN** generating a code for an account raises an error
- **THEN** the tile shows an unavailable indication instead of a stale or invented code, and a subsequent refresh is still scheduled

#### Scenario: Failure is not silent

- **WHEN** generation fails for an account
- **THEN** the failure is recorded in the application log with enough context to identify the account

#### Scenario: Recovery after a transient failure

- **WHEN** a later refresh succeeds after a failure
- **THEN** the tile displays the new code again
