# Spec Delta

## Purpose

Make account creation work offline-first: a newly created account becomes available in the
local list immediately, can show its code when the secret is local, and is uploaded and
reconciled with the server automatically once connectivity returns.

## ADDED Requirements

### Requirement: New accounts appear immediately

The system SHALL add and persist a newly created account to the selected server's local
account list as soon as the creation flow returns it, without waiting for a server response or
for a synchronization cycle.

#### Scenario: Created while offline

- **WHEN** the user completes an account creation flow with no connectivity
- **THEN** the account appears in the list immediately with the existing pending-upload
  indicator and remains present after an app restart

#### Scenario: Created while online

- **WHEN** the server accepts the account during creation
- **THEN** the account appears in the list immediately, without waiting for a full account
  synchronization to finish

#### Scenario: Created account is not discarded

- **WHEN** the creation flow returns a local account because the upload failed
- **THEN** that account is stored in the selected server's account list instead of being
  ignored

### Requirement: Pending accounts remain usable

While an account is pending upload, the system SHALL keep the locally captured OTP material
and SHALL generate its code locally when that material is available. The pending state MUST be
shown with the existing indicator and MUST NOT block code display.

#### Scenario: Pending TOTP shows a code

- **WHEN** a TOTP account with a local secret is pending upload
- **THEN** its tile shows the same current code it would show after synchronization

#### Scenario: Pending HOTP shows a code

- **WHEN** a HOTP account with a local secret is pending upload
- **THEN** requesting its code produces a code from the local counter instead of an offline
  or unavailable message

#### Scenario: Account without a local secret

- **WHEN** an account has no locally available secret
- **THEN** the existing behavior for server-provided codes is preserved; the pending account
  does not generate a code from an empty secret

### Requirement: Pending accounts have distinct local identities

Each locally created account that has not been uploaded SHALL have a local identifier unique
within its server. The identifier MUST survive restarts and MUST distinguish pending entries
for display, selection, editing, and deletion until the server assigns a permanent id.

#### Scenario: Multiple accounts created offline

- **WHEN** the user creates two accounts while offline
- **THEN** both appear as separate list items and can be selected or acted on independently

#### Scenario: Restart with pending accounts

- **WHEN** the app restarts with several pending accounts stored
- **THEN** every pending account is still listed separately with its own code and pending
  indicator

### Requirement: Pending uploads are retried automatically

The system SHALL attempt to upload every local-only unsynced account immediately after
creation, on app startup and foreground resume when such accounts exist, and through bounded
automatic retries while the app is running. Retrying MUST NOT depend on the user enabling
sync-on-open or automatic synchronization, and MUST stop when no pending account remains.

#### Scenario: Connectivity returns

- **WHEN** an account was created while offline and the server becomes reachable while the app
  is running
- **THEN** the account is uploaded automatically without the user pressing sync or
  pull-to-refresh

#### Scenario: Synchronization settings are disabled

- **WHEN** sync-on-open and automatic synchronization are both disabled and a pending account
  exists
- **THEN** the pending upload is still attempted and retried until it succeeds

#### Scenario: Resume after being offline

- **WHEN** the app returns to the foreground with pending accounts and the server is now
  reachable
- **THEN** the pending accounts are uploaded without requiring a manual sync

#### Scenario: Retry stops when nothing is pending

- **WHEN** the last pending account has been uploaded
- **THEN** no further automatic upload retries are scheduled

### Requirement: Server acceptance reconciles the local account

When the server accepts a pending account, the system SHALL replace the local pending record
with the server record, mark it synchronized, and remove the pending indicator. Locally
captured secret and OTP parameters MUST be retained when the server response omits them. The
reconciliation MUST NOT create a duplicate entry and MUST NOT require a full account download.

#### Scenario: Pending account becomes synchronized

- **WHEN** the server creates a pending account successfully
- **THEN** the same list entry receives the server id, loses the pending indicator, and keeps
  its position and displayed code

#### Scenario: Creation response omits the secret

- **WHEN** the server's creation response does not include the secret or OTP parameters
- **THEN** the locally captured secret and parameters remain in the stored account and its
  code continues to work offline

#### Scenario: No duplicate after reconciliation

- **WHEN** the account has been reconciled and a later synchronization fetches the server list
- **THEN** the account appears exactly once

### Requirement: Full synchronization preserves pending entries

A synchronization that replaces the local account list with server data SHALL preserve local
accounts that are still pending upload, so a failed or partial upload does not remove them.
Once an account is accepted by the server, the server record SHALL replace the pending record.

#### Scenario: Server reachable but upload fails

- **WHEN** a full synchronization fetches the server list while a local account is still
  pending because its creation request failed
- **THEN** the pending account remains in the list after synchronization and is still marked
  for upload

#### Scenario: Upload succeeds during synchronization

- **WHEN** synchronization uploads a pending account and then fetches the server list
- **THEN** the list contains the server-backed account once and no leftover pending copy

### Requirement: Local-only accounts can be removed without a server call

Deleting an account that has never been uploaded SHALL remove it locally, without calling the
server and without leaving a deletion marker that would be retried forever.

#### Scenario: Delete a pending account

- **WHEN** the user deletes a pending account that has no server id
- **THEN** it disappears from the list immediately and no server delete request is attempted

#### Scenario: Deleted pending account stays gone

- **WHEN** the app restarts or synchronizes after a pending account was deleted
- **THEN** the account does not reappear and no retry is scheduled for it
