# Design

## Context

See `proposal.md` — Why. The current pipeline in `lib/screens/image_qr_scanner_screen.dart`:

```
ImagePicker -> read bytes -> image.decodeImage -> resize to 1500 -> adjustColor
            -> encodeJpg + temp file -> flutter_zxing readBarcodeImagePathString
            -> plugin: decodeImage(temp jpg) -> resizeToMaxSize(maxSize) -> RGB -> native scan
```

Relevant constraints from `flutter_zxing` 3.1.0 / zxing-cpp 3.1.1:

- `DecodeParams.maxSize` only applies to file and URL decoding (`image_decoder.dart`); camera
  frames are passed to the native decoder at their native size.
- The plugin decodes the file with the pure-Dart `image` package, then `resizeToMaxSize` uses
  `copyResize` with its default (nearest) interpolation, converts to RGB, and scans.
- The native decoder uses a LocalAverage binarizer and an internal pyramid (downscales while the
  longest side exceeds 500 px), so it already handles large images and multiple scales.
- The plugin defaults `maxSize` to 768 when the caller does not set it; the app sets 3000, which
  is a no-op because the image was already reduced to 1500.

The camera path (`qr_scanner_screen.dart`) passes frames with their native width/height and is
the reference for reliability.

## Goals / Non-Goals

**Goals:**

- Make file scanning use the image's available resolution so a QR that the camera could read is
  not lost to an app-side downscale.
- Remove the redundant decode/resize/encode/temp-file work from the image path.
- Keep the existing OTP parsing, server upload, and error messages unchanged.

**Non-Goals:**

- HEIC/AVIF decoding, multi-QR selection, or user-facing crop UI.
- Changing the camera scanner, `EntryCreationService`, or the localization strings.
- Reworking the plugin or replacing zxing-cpp.

## Decisions

### Decision 1: Scan the original file, with a high safety bound

Replace the app-side preprocessing with a single call:

```dart
final codeResult = await zx.readBarcodeImagePathString(
  image.path,
  DecodeParams(
    tryHarder: true,
    tryInverted: true,
    tryRotate: true,
    tryDownscale: true,
    maxSize: 4000,
  ),
);
```

`maxSize: 4000` is a safety bound, not a detection aid:

- All common screenshots (up to 4K, 3840 px longest side) and 12 MP phone photos (4032 px) are
  effectively untouched.
- Long/scrolling screenshots are reduced less aggressively than today (e.g. 1080x9000 becomes
  480x4000, keeping a 300 px QR at ~133 px) instead of the current 1500 px cap (which left it at
  50 px).
- It bounds the RGB buffer handed to the native decoder for pathological images.

Alternatives rejected:

- **Keep the app-side pipeline with a higher cap.** It still requires a full decode, a resize, a
  JPEG encode, a temp file, and a second decode — strictly more work than one decode, and still
  lossy.
- **`maxSize: 0` (no bound).** Maximum fidelity, but leaves the RGB buffer unbounded for very
  large images. 4000 covers every realistic screenshot and phone photo without a practical
  detection loss; revisit only if a real case needs more.
- **Progressive low-to-high passes.** The low-resolution pass is exactly the current bug; doing
  it first would add a second decode to every failing scan. The full-resolution pass is both the
  most accurate and sufficient because the decoder already has its own pyramid.

### Decision 2: Keep the existing decoder flags

`tryHarder`, `tryRotate`, `tryInverted`, and `tryDownscale` stay enabled. They are orthogonal to
resolution: inversion covers dark-theme QR codes, rotation covers camera/EXIF orientation, and
`tryDownscale` lets zxing scan its own downscaled pyramid.

### Decision 3: Remove the contrast/brightness boost and the temporary JPEG

`adjustColor(contrast: 1.3, brightness: 1.1)` and the `processed_qr.jpg` write exist only to feed
the old pipeline. The ML Kit implementation already noted that ML Kit did not need the boost, and
the measurements for this change showed it is neutral-to-harmful depending on glare. Removing it
also removes the requirement that the picked file's directory be writable and the second decode
of the re-encoded JPEG.

### Decision 4: Preserve the success/failure contract

`_parseAndCreateEntry` and its call sites stay as they are: valid `otpauth://` content creates the
entry and uploads it when a server is configured; unparseable content reports the parse error;
no detected QR reports "no QR in image". The plugin returns an invalid `Code` (with `error`) for
unreadable files rather than throwing; that remains reported as "no QR", matching today's
behavior. Distinguishing unreadable files from genuinely QR-less images is a separate improvement.

## Risks / Trade-offs

- **Peak memory for large photos** → The full image decoded by `image` and the RGB copy coexist
  (roughly 6 bytes per pixel). A 12 MP photo peaks around 72 MB; `maxSize: 4000` bounds the RGB
  copy for larger inputs. The current code already decodes the full image in Dart, so this is not
  a new class of memory use; monitor low-end devices.
- **Main-isolate decode** → `readBarcodeImagePathString` decodes with the `image` package on the
  calling isolate. The current code also does a full decode there, and removing the resize/encode
  offsets part of the cost. If jank appears on large photos, moving the decode to an isolate is a
  follow-up, not a blocker.
- **Nearest-neighbour resize above 4000 px** → The plugin uses `copyResize`'s default
  interpolation. Tested long screenshots still decode at the 4000 px bound. If artifacts matter,
  pre-resize in the app with a linear filter in a later change.
- **Physical limits remain** → Blur, glare, or a QR rendered too small to resolve cannot be fixed
  by resolution alone; cropping may still help in those cases. This change removes the artificial
  loss, not the physical one.
- **Detection behavior on old devices** → Full-resolution scans take longer than 1500 px scans
  (native-only cost; measured ~45-50 ms for 12 MP vs ~6 ms). The removed Dart-side work more than
  offsets it for screenshots.

## Migration Plan

No data, API, dependency, or storage changes. The change is confined to the image scanner screen
and can be rolled back by reverting that file. No feature flag is needed.
