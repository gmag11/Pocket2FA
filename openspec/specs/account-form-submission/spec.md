# account-form-submission Specification

## Purpose

Governs how the manual account form submits create and update actions: every action produces at
most one request and one resulting account, the in-progress state is visible, and the form leaves
exactly once when the action completes.

## Requirements

### Requirement: Submission is single-flight

The manual account form SHALL process at most one create or update request for the duration of a
user action. While a request is pending, additional presses of the submit action MUST NOT send
another server request, build another local account, or enqueue another result.

#### Scenario: Repeated presses during a slow server response

- **WHEN** the user presses Create for a HOTP account and presses it again before the server
  responds
- **THEN** only one creation request is sent and only one account is created

#### Scenario: Repeated presses while updating

- **WHEN** the user presses Update and presses it again before the server responds
- **THEN** only one update request is sent and the form returns a single updated account

#### Scenario: Validation failure does not submit

- **WHEN** the user presses the submit action with invalid form data
- **THEN** validation messages are shown and no request is started

### Requirement: Pending submission is visible and blocks exit

While a create or update request is pending, the form SHALL indicate that the action is in
progress, SHALL disable the submit action, and SHALL prevent the user from leaving the form
through its Cancel action or back navigation.

#### Scenario: In-flight feedback

- **WHEN** a create request is pending
- **THEN** the submit action is disabled and shows a progress indicator instead of the idle
  Create or Update label

#### Scenario: Exit blocked while pending

- **WHEN** a request is pending and the user presses Cancel or the back button
- **THEN** the form stays open and the pending request is not abandoned

#### Scenario: Actions restored on failure

- **WHEN** submission ends without returning an account
- **THEN** the form stays open, the submit action is enabled again, and the user can retry

### Requirement: Completion navigates exactly once

When submission completes with a resulting account, the form SHALL return that account to its
caller exactly once, whether the account came from the server or from the local offline-first
fallback.

#### Scenario: Successful server creation

- **WHEN** the server accepts the account
- **THEN** the form closes once with the server-backed account

#### Scenario: Offline creation fallback

- **WHEN** the server request fails but the local account is built
- **THEN** the form closes once with the local unsynced account, preserving existing offline
  creation behavior

#### Scenario: No extra navigation after closing

- **WHEN** the form has returned its account
- **THEN** no later completion of the same submission closes another screen
