# Proposal

## Why

Today the only way to create an account from an image is to open Pocket2FA, tap the new-code
button, choose "Select Image", and browse to the file again. The image usually already exists in
the app the user is looking at — a gallery, a browser, a chat, a screenshot tool, or a file
manager — so the current flow makes the user leave that context and re-find the file. On desktop,
files are commonly dragged onto apps, and Pocket2FA ignores those drops entirely.

Accepting the image where the user already has it removes that round trip on both mobile and
desktop, while reusing the existing full-resolution QR pipeline and account-creation flow.

## What Changes

- **Android share target:** Pocket2FA accepts a shared image (`ACTION_SEND` / `ACTION_SEND_MULTIPLE`
  with `image/*`) from other apps, both when it is already running and on cold start. The
  `content://` payload is copied to app-private cache, then handed to Dart.
- **Desktop drag-and-drop:** the main accounts screen accepts an image file dropped anywhere in
  the UI on Windows and Linux, with a visible drop affordance while dragging.
- **Single image only:** receiving or dropping more than one image rejects the entire batch and
  reports that only one image is supported. Nothing is created.
- **Automatic processing:** a single accepted image is scanned with the same ZXing pipeline and
  resolution bounds as gallery scanning. A valid `otpauth://` QR is created and uploaded through
  the existing flow; the account list is updated and the usual confirmation is shown. If the
  server is unreachable, the account is still added locally as a pending upload, exactly like any
  other creation, and is uploaded automatically when the server returns.
- **Clear failure outcomes:** non-image content, oversized files, unreadable images, images with
  no QR, and non-OTP QR content each produce a localized message and no account.
- **Server and lock safety:** the image is not processed while encrypted storage is locked; it is
  held until unlock and then processed once. With no configured server, the app explains that a
  server is required instead of creating an unreachable local entry.
- **Temporary-file hygiene:** shared/dropped copies live in app cache and are deleted after
  processing, on failure, and when stale files are found at startup.
- Gallery selection, camera scanning, OTP parsing, server upload, and existing account behavior
  are unchanged.

## Capabilities

### New Capabilities

- `qr-image-ingest`: receiving a single image from an external source (Android share intent or
  desktop drag-and-drop), validating it, handing it to QR scanning, and reporting accept/reject
  outcomes without bypassing lock or server requirements.

### Modified Capabilities

- `qr-image-scanning`: scanning guarantees now explicitly cover images that arrive by share or
  drop, so external images are decoded with the same resolution and produce the same outcomes as
  gallery-selected images.

## Impact

- **Affected code:** `android/app/src/main/AndroidManifest.xml` and
  `android/app/src/main/kotlin/net/gmartin/pocket2fa/MainActivity.kt` (share intent and method
  channel); `lib/main.dart` or `lib/screens/home_screen.dart` (intake wiring and drop target);
  new intake/processing services under `lib/services/`; `lib/screens/image_qr_scanner_screen.dart`
  (extract the scan call so both entry points share it); `lib/l10n/app_{en,es,fr}.arb` and
  generated localizations (new messages).
- **Dependencies:** add `desktop_drop` (^0.9.2, Windows/Linux drag-and-drop); no Android share
  plugin is added — the share intent is handled natively in `MainActivity`.
- **Platforms:** Android, Windows, and Linux. There is no iOS target in this repository, so no
  iOS share extension is added.
- **Behavioral risk:** receiving untrusted files, double-processing a share that arrives during
  startup or unlock, and leaving cache copies behind. The design addresses each with a single
  queued intake, size limits, and deterministic cleanup.
- **No API, data, or storage migration.** No new permissions are required (only the existing
  `INTERNET`, `CAMERA`, and legacy gallery permission remain).
