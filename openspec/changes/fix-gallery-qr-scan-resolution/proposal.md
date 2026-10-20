# Proposal

## Why

Scanning a QR from a saved image (typically a phone screenshot) fails unless the image is
cropped tightly around the QR, while the camera scanner works reliably. The image path is the
only one that shrinks the input: `ImageQrScannerScreen` resizes every image to a 1500 px longest
side before decoding (`lib/screens/image_qr_scanner_screen.dart:59-71`), a leftover from the
ML Kit implementation that is no longer justified with ZXing. When the QR occupies a small part
of the image — a long/scrolling screenshot, a high-resolution capture, or a QR rendered small on
the page — the resize reduces it below the ~2-3 px/module the decoder needs, and detection fails.
Cropping bypasses the limit and preserves the QR's original pixels, which is why it works.

The camera path proves the limit is unnecessary: `ReaderWidget` passes camera frames at their
native resolution and the decoder handles them fine. The image path also pays more work than the
camera: it decodes the original, resizes it, boosts contrast, re-encodes a JPEG, writes a temp
file, and then the plugin decodes that JPEG again. Removing the pre-resize will make image
scanning both more reliable and no slower.

## What Changes

- Decode gallery images at their native resolution: remove the 1500 px pre-resize from the image
  scanner, or replace it with a high safety bound (e.g. 4000-6000 px) that does not affect normal
  screenshots.
- Remove the intermediate pipeline that only exists because of the resize: the unconditional
  contrast/brightness adjustment, the JPEG re-encode, and the temporary `processed_qr.jpg`.
- Let the plugin scan the original file (`maxSize: 0`), avoiding its nearest-neighbour resize and
  the second decode.
- Keep the existing decoder options (`tryHarder`, `tryRotate`, `tryInverted`, `tryDownscale`) and
  the existing success/error handling (parse `otpauth://`, upload, snackbars).
- Image scanning must behave like camera scanning for the same QR content: no resolution-based
  failures that the camera does not have.
- If a very large image (e.g. a 100+ MP photo) needs a guard, it must fall back to a downscaled
  pass only after the full-resolution attempt, never before.

## Capabilities

### New Capabilities

- `qr-image-scanning`: scanning QR codes from image files (screenshots, downloads, photos) at
  full available resolution, with the same detection reliability as the camera scanner.

### Modified Capabilities

<!-- None: camera scanning, OTP parsing, server upload, and error handling keep their behavior. -->

## Impact

- **Affected code:** `lib/screens/image_qr_scanner_screen.dart` (decode pipeline). No changes
  expected in `qr_scanner_screen.dart`, `entry_creation_service.dart`, or the localization files.
- **No new dependencies**, no API changes, no data migration, no breaking changes.
- **Performance:** removes one full-image decode, one resize, one JPEG encode, one file write, and
  one JPEG decode. Peak memory rises only for very large photos (a 12 MP RGB buffer is ~36 MB);
  screenshots are ~8-25 MB.
- **Not covered:** HEIC/AVIF decoding support and multi-QR selection (the scanner still returns the
  first detected QR). Those are separate concerns if they turn out to matter.
