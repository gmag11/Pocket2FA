# Tasks

## 1. Replace the image decode pipeline

- [x] 1.1 In `lib/screens/image_qr_scanner_screen.dart`, replace the block that reads the file, resizes it to 1500 px, adjusts contrast/brightness, and writes `processed_qr.jpg` with a single `zx.readBarcodeImagePathString(image.path, DecodeParams(tryHarder: true, tryInverted: true, tryRotate: true, tryDownscale: true, maxSize: 4000))`; verify `flutter analyze` passes and the screen no longer contains a temp-file write.
- [x] 1.2 Remove the imports and cleanup code that become unused (`dart:io`, `package:image/image.dart`, `processedImagePath`, the `finally` file deletion); verify `flutter analyze` reports no unused imports or variables.
- [x] 1.3 Confirm the decoder flags are exactly `tryHarder`, `tryInverted`, `tryRotate`, and `tryDownscale`, and that no fixed 1500 px resize remains in the screen; verify with `grep -n "1500\|processed_qr\|adjustColor" lib/screens/image_qr_scanner_screen.dart` returning no matches.
- [x] 1.4 Review the diff to confirm `_parseAndCreateEntry`, `EntryCreationService` calls, localization keys, and snackbar behavior are unchanged; verify `git diff --stat` touches only `image_qr_scanner_screen.dart`.

## 2. Acceptance verification with sample images

- [x] 2.1 Baseline: scan a tightly cropped QR screenshot and verify an entry is created and returned to the caller.
- [x] 2.2 Scan an uncropped 1080x2400 screenshot with the QR embedded among app bars, lists, and text; verify it is detected without cropping.
- [x] 2.3 Scan a long/scrolling screenshot (for example 1080x6000 or 1080x9000) whose QR is small in the image; verify it is detected. Confirm the same file failed on the previous build.
- [x] 2.4 Scan a high-resolution screenshot (1440x3200 and/or 2160x3840) containing a QR; verify it is detected.
- [x] 2.5 Scan an image containing a non-otpauth QR and an image with no QR; verify the existing parse error and "no QR in image" messages appear.
- [x] 2.6 Scan a dark/inverted QR screenshot and a rotated QR photo; verify both are still detected, confirming `tryInverted` and `tryRotate` remain effective.
- [x] 2.7 Scan a 12 MP photo with a QR; verify the app completes without an out-of-memory crash and note the observed scan time on the target device.
- [x] 2.8 Run the same failing sample on the previous build and on this branch; verify the old build reports no QR and the new build creates the entry.

## 3. Cleanup

- [x] 3.1 Remove or rewrite comments that describe the old 1500 px resize and the preprocessed temp image; verify the remaining comments describe the single-pass original-file decode.
- [x] 3.2 Verify no localization files or other screens changed: `git diff --name-only` lists only `lib/screens/image_qr_scanner_screen.dart` (plus the OpenSpec artifacts).

## Workflow follow-up

- Run `flutter analyze` on the branch.
- Run `openspec validate fix-gallery-qr-scan-resolution --strict` after the change is applied.
- Build and smoke-test the Android APK; the image picker path is the target, so a real-device check matters more than desktop.
- Archive the change once review and verification are complete.
