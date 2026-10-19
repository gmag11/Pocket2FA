# Spec Delta

## Purpose

Ensure accounts shared with the authenticated user through 2FAuth are presented as read-only and visually identified as shared, matching the server's authorization rules and preventing edits or deletions that cannot be saved.

## ADDED Requirements

### Requirement: Borrowed accounts offer no edit affordance

The client SHALL NOT present any control that opens the account edit form for an account shared with the authenticated user (identified by `is_borrowed`), regardless of its OTP type.

#### Scenario: No edit action for a shared TOTP account

- **WHEN** a borrowed TOTP account is shown in manage mode
- **THEN** the tile does not show an edit action for it

#### Scenario: No edit action for a shared HOTP account

- **WHEN** a borrowed HOTP account is shown in manage mode
- **THEN** the tile does not show an edit action for it

#### Scenario: Owned accounts keep their edit action

- **WHEN** an owned account is shown in manage mode
- **THEN** its edit action is shown and works as before

### Requirement: Edit requests for borrowed accounts are rejected

Even if an edit is requested through a path other than the tile control, the client SHALL NOT open the edit form for a borrowed account.

#### Scenario: Navigation guard

- **WHEN** the edit flow is invoked for an account marked as borrowed
- **THEN** the client stays on the current screen and does not open the edit form

#### Scenario: Form guard

- **WHEN** the edit form is asked to open with a borrowed account as its existing entry
- **THEN** the form does not allow editing that account

### Requirement: Borrowed account data remains unchanged by the client

A borrowed account SHALL keep the values returned by the server; the client MUST NOT produce a locally modified copy of it through the edit flow.

#### Scenario: No local unsynced copy after an attempted edit

- **WHEN** an edit is attempted on a borrowed account and rejected by the client
- **THEN** no locally modified account entry is created or persisted

### Requirement: Borrowed accounts cannot be deleted

The client SHALL NOT allow an account shared with the authenticated user to be selected for deletion or included in a delete operation, and MUST NOT create a local deletion marker for it.

#### Scenario: Borrowed account has no selection control in manage mode

- **WHEN** manage mode is active and a borrowed account is displayed
- **THEN** no selection checkbox is shown for it and the account cannot be selected for deletion

#### Scenario: Bulk deletion excludes borrowed accounts

- **WHEN** a delete operation is issued while a borrowed account is part of the current selection
- **THEN** only owned accounts are marked and sent for deletion

#### Scenario: Owned accounts remain deletable

- **WHEN** an owned account is selected in manage mode and deletion is confirmed
- **THEN** it is deleted as before

#### Scenario: Stale pending deletion of a borrowed account

- **WHEN** local storage still contains a pending deletion marker for a borrowed account
- **THEN** the client does not send its deletion to the server and restores it from the next synchronization

### Requirement: Shared accounts are visually identified

The client SHALL display an indicator icon immediately to the left of the account username when the account is shared with the authenticated user, in both normal and manage modes and for both TOTP and HOTP accounts.

#### Scenario: Shared account shows the indicator

- **WHEN** a borrowed account is displayed
- **THEN** an icon appears immediately before its username, with a tooltip explaining that the account is shared

#### Scenario: Owned account shows no indicator

- **WHEN** an owned account is displayed
- **THEN** no shared indicator is shown before its username

