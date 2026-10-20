# shared-account-otp Specification

## Purpose

Ensure accounts whose secrets are not available locally (accounts shared with the authenticated user by other users of the same 2FAuth instance) display their real One-Time Passwords instead of a code derived from an empty seed.

## Requirements

### Requirement: Shared accounts are identified after synchronization

The system SHALL identify, from the accounts returned by the server, which ones are shared with the authenticated user, using the server-provided sharing properties (`is_borrowed` and `shared_by`). This identification MUST be preserved in local storage so the distinction survives app restarts and offline use.

#### Scenario: Account shared with the user is marked as borrowed

- **WHEN** the server returns an account with `is_borrowed` set to true and a `shared_by` value
- **THEN** the client stores that account as borrowed and keeps the name of the user who shared it

#### Scenario: Owned account is not marked as borrowed

- **WHEN** the server returns an account without the `is_borrowed` property
- **THEN** the client treats it as an owned account

#### Scenario: Borrowed flag survives a round trip through local storage

- **WHEN** a borrowed account is persisted and later loaded from local storage
- **THEN** it is still identified as borrowed along with its `shared_by` value

### Requirement: Shared TOTP codes are obtained from the server

For a TOTP account shared with the user (identified as borrowed, or having no locally available secret), the system SHALL display the One-Time Password returned by the server's One-Time Password endpoint for that account, rather than a code generated locally from the account's (empty) secret. Different shared accounts MUST NOT display the same code merely because their local secrets are empty.

#### Scenario: Shared TOTP shows its own code

- **WHEN** two different TOTP accounts are shared with the user and both are displayed
- **THEN** each shows the code returned by the server for its own account id, and the two codes are not forced to be equal

#### Scenario: Shared TOTP matches the server value

- **WHEN** a TOTP account is shared with the user and the server returns a code for it
- **THEN** the code displayed by the client equals the server-returned current code

#### Scenario: Shared TOTP shows the next code

- **WHEN** the server response for a shared TOTP includes a next password
- **THEN** the client displays that value as the next code

### Requirement: Shared code refresh follows the server-reported period

The system SHALL refresh a shared TOTP account's displayed code aligned to the period boundary derived from the server-reported generation time and period, so that the code advances at the same instant as the server's code. Because the server reports the generation instant rather than the start of the period, the next refresh MUST occur at the next period boundary on the server timeline, not a full period after the request.

#### Scenario: Code refreshes at the next server period boundary

- **WHEN** the server returns a code generated at time `generated_at` with a period of `period` seconds
- **THEN** the client requests a fresh code at the next boundary (`generated_at - generated_at % period + period`) and updates the display, regardless of how far into the period the original request was made

#### Scenario: Fetch late in the period

- **WHEN** the first code for a shared account is fetched near the end of a period
- **THEN** the client replaces it at the imminent boundary instead of keeping it until the same phase of the next period, so it never displays the server's current code as the next code

### Requirement: Graceful degradation when a shared code cannot be fetched

When a shared TOTP account's code cannot be obtained from the server, the system MUST NOT display a code computed from an empty secret. It SHALL instead present an unavailable/offline indication until a code can be fetched again.

#### Scenario: Server unreachable for a shared account

- **WHEN** the client attempts to fetch a shared account's code and the request fails
- **THEN** the account tile shows an unavailable/offline indication instead of an incorrect code

#### Scenario: Recovery when connectivity returns

- **WHEN** connectivity is restored and the client successfully fetches the shared account's code
- **THEN** the tile displays the fetched code again

### Requirement: Owned accounts continue to generate codes locally

The change SHALL NOT alter how accounts whose secret is available locally are handled: their codes MUST continue to be generated on the device and remain available offline.

#### Scenario: Owned TOTP works offline

- **WHEN** an owned TOTP account is displayed while the device has no network connection
- **THEN** its code is still generated locally and shown, unchanged from previous behavior
