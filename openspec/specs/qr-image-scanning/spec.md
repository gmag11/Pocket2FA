# qr-image-scanning Specification

## Purpose

Scanning QR codes from image files — screenshots, downloads, and photos — at the image's
available resolution, with the same detection reliability the camera scanner provides, so that
surrounding content or image size never decides whether a valid QR is recognized.

## Requirements

### Requirement: Image scanning preserves source resolution

The image QR scanner SHALL decode the selected image at its stored resolution, or at a safety
bound high enough to retain the module detail of any QR the source image contains. It MUST NOT
pre-emptively reduce an image to a fixed small size before detection.

#### Scenario: Small QR in a long screenshot

- **WHEN** the user selects a tall or scrolling screenshot whose QR occupies a small fraction of the image
- **THEN** the scanner detects the QR instead of reporting that the image contains no QR code

#### Scenario: High-resolution screenshot

- **WHEN** the user selects a high-resolution screenshot (for example 1440x3200 or 2160x3840) containing a QR
- **THEN** the QR is detected without requiring the user to crop the image

#### Scenario: Very large image keeps enough detail

- **WHEN** an image is large enough to require a memory safety bound
- **THEN** the bound still preserves enough module detail for the QR to be decoded

### Requirement: Surrounding content does not affect detection

The scan result SHALL depend on the QR content in the image, not on how much unrelated UI, text,
or background surrounds it. A QR embedded in a full screenshot MUST be detected exactly as it is
when the same pixels are cropped to the QR.

#### Scenario: QR embedded in a screenshot

- **WHEN** the selected screenshot contains the QR together with app bars, lists, text, or other page content
- **THEN** the scanner detects the QR and continues with the entry creation flow

#### Scenario: Cropped and uncropped forms agree

- **WHEN** the user scans an image containing a QR and then scans a crop of that same image around the QR
- **THEN** both scans produce the same QR content

### Requirement: Existing outcomes are preserved

Scanning from an image SHALL keep the existing outcomes: valid `otpauth://` content creates the
entry and uploads it when a server is configured, unrecognized content reports a parse error, and
an image with no detectable QR reports that no QR was found.

#### Scenario: Valid QR creates an entry

- **WHEN** the detected QR contains a valid otpauth URI
- **THEN** the entry is created, uploaded when a server is configured, and returned to the caller

#### Scenario: No QR found

- **WHEN** the image contains no detectable QR code
- **THEN** the user sees the existing "no QR in image" message and remains on the image picker screen

#### Scenario: Non-OTP content

- **WHEN** the image contains a QR whose content is not a valid otpauth URI
- **THEN** the user sees the existing parse error instead of a silent failure
