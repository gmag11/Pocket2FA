# Spec Delta

## ADDED Requirements

### Requirement: External image sources share scanning guarantees

An image accepted from a share or a desktop drop SHALL be decoded with the same resolution
policy, decoder options, and error outcomes as an image selected from the gallery. The intake
source MUST NOT change how the image is scanned or lower the detail available for detection.

#### Scenario: Shared small QR in a large screenshot

- **WHEN** a shared image contains a QR that occupies a small part of a large screenshot
- **THEN** it is detected with the same reliability as when the same image is selected from the gallery

#### Scenario: Dropped image matches gallery selection

- **WHEN** the same image file is first dropped onto the desktop app and later selected through the gallery picker
- **THEN** both scans produce the same QR content and the same account outcome

#### Scenario: Incoming image outcomes match gallery outcomes

- **WHEN** an incoming image contains a valid OTP QR, no QR, or a non-OTP QR
- **THEN** it produces the same create, no-QR, or parse-error outcome as the gallery path
