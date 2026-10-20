# Spec Delta

## Purpose

Receiving a single image from outside Pocket2FA — shared from another Android app or dropped onto
the desktop window — validating it, handing it to the existing QR pipeline, and reporting clear
accept or reject outcomes without bypassing lock or server requirements.

## ADDED Requirements

### Requirement: Android share intake

The app SHALL accept a single image shared from another Android app, both while it is already
running and when the share launches it, and SHALL make that image available for QR scanning
without requiring the user to browse for the file again.

#### Scenario: Image shared while the app is running

- **WHEN** the user shares one image to Pocket2FA from another app while Pocket2FA is already running
- **THEN** Pocket2FA comes to the foreground and processes the image automatically

#### Scenario: Image shared on cold start

- **WHEN** the user shares one image to Pocket2FA while the app is not running
- **THEN** the app starts, completes its normal initialization, and processes the shared image without another user action

#### Scenario: Share delivers multiple images

- **WHEN** a share delivers more than one image
- **THEN** the app rejects the whole share, reports that only one image is allowed, and creates no account

### Requirement: Desktop drop intake

On Windows and Linux, the desktop app SHALL accept one image file dropped anywhere on the main
accounts screen and SHALL show a visible drop affordance while a file is dragged over the window.

#### Scenario: Single image dropped

- **WHEN** the user drops one image file onto the main accounts screen
- **THEN** the app accepts the file and processes it automatically

#### Scenario: Non-image file dropped

- **WHEN** the user drops a file that is not an image
- **THEN** the app rejects it with a message and creates no account

#### Scenario: Multiple files dropped

- **WHEN** the user drops more than one file
- **THEN** the app rejects the whole drop, reports that only one image is allowed, and creates no account

#### Scenario: Drag hover affordance

- **WHEN** a file drag enters the app window and then leaves or is dropped
- **THEN** a drop affordance appears on entry and disappears after the drag leaves or the drop completes

### Requirement: Single image per intake

The app SHALL process at most one image for each share or drop. An intake that delivers more than
one image SHALL be rejected entirely, and an intake that delivers no usable image SHALL be
rejected with a message. No account SHALL be created from a rejected intake.

#### Scenario: Extra images are never processed

- **WHEN** an intake contains two or more images and one of them holds a valid OTP QR
- **THEN** none of the images is scanned and no account is created

#### Scenario: Empty intake

- **WHEN** a drop or share arrives without a readable file
- **THEN** the app reports that no usable image was received and creates no account

### Requirement: Incoming image processing

For an accepted image, the app SHALL scan for a QR code and, when the content is a valid OTP URI,
create the entry, upload it when a server is configured, add it to the current server's account
list, and confirm the addition. While the image is being scanned, the app SHALL indicate that
processing is in progress.

#### Scenario: Valid OTP QR from a share

- **WHEN** a shared image contains a valid `otpauth://` QR and a server is configured
- **THEN** the entry is created and uploaded, appears in the current account list, and the usual confirmation is shown

#### Scenario: Valid OTP QR from a drop

- **WHEN** a dropped image contains a valid `otpauth://` QR and a server is configured
- **THEN** the entry is created and uploaded, appears in the current account list, and the usual confirmation is shown

#### Scenario: Processing indicator

- **WHEN** an accepted image is being scanned and uploaded
- **THEN** the app shows that processing is in progress and does not accept another image until it finishes

#### Scenario: Image without a QR code

- **WHEN** an accepted image contains no detectable QR code
- **THEN** the app reports that no QR was found and creates no account

#### Scenario: QR content that is not an OTP URI

- **WHEN** an accepted image contains a QR whose content is not a valid OTP URI
- **THEN** the app reports the existing parse error and creates no account

### Requirement: Server requirement for incoming images

When no server is configured, the app SHALL tell the user that a server is required before an
account can be added from a shared or dropped image, and SHALL NOT create a local-only entry.

#### Scenario: No configured server

- **WHEN** an image arrives while no server is configured
- **THEN** the app explains that a server must be added first and creates no account

### Requirement: Locked storage blocks processing

While encrypted storage is locked, the app SHALL NOT create an account from an incoming image.
It SHALL retain the accepted image until the user unlocks the app and then process it exactly
once.

#### Scenario: Share arrives while locked

- **WHEN** an image is shared while the PIN or biometric lock is active
- **THEN** the lock screen remains in control and the image is processed only after a successful unlock

#### Scenario: Image is not processed twice

- **WHEN** a retained image is processed after unlock
- **THEN** exactly one account is created or one error is reported for that image

### Requirement: Incoming image safety and cleanliness

The app SHALL treat an incoming image as untrusted data, SHALL accept only images up to a fixed
size limit, and SHALL store its working copy only in app-private cache. The working copy SHALL be
deleted after processing or failure, and stale copies SHALL be removed at startup.

#### Scenario: Oversized image

- **WHEN** an incoming image exceeds the accepted size limit
- **THEN** the app rejects it with a message before decoding and creates no account

#### Scenario: Unreadable image

- **WHEN** an accepted image cannot be decoded
- **THEN** the app reports that the image could not be read and creates no account

#### Scenario: Working copy cleanup

- **WHEN** processing of an incoming image ends, successfully or not
- **THEN** its app-private working copy is deleted

#### Scenario: Stale copy cleanup

- **WHEN** the app starts and app-private cache contains leftover incoming-image files
- **THEN** those files are removed before any new image is processed

### Requirement: Incoming images stay local

The app SHALL NOT upload the received image itself. Only the OTP fields parsed from a detected QR
SHALL be sent to the configured server, and decoded secrets SHALL NOT be written to logs.

#### Scenario: Only parsed fields reach the server

- **WHEN** an incoming image is processed with a configured server
- **THEN** the image file is not transmitted and only the parsed account fields are sent

#### Scenario: Secrets stay out of logs

- **WHEN** a QR is decoded from an incoming image
- **THEN** any diagnostic logging masks the OTP secret
