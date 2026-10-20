# Design

## Context

See `proposal.md` — Why. The current image path is:

```
NewCodeScreen -> ImageQrScannerScreen -> ImagePicker -> zx.readBarcodeImagePathString(maxSize: 4000)
             -> EntryCreationService.parseOtpAuthUrl -> createEntryOnServer -> pop(AccountEntry)
             -> NewCodeScreen -> HomePage -> HomeServerManager.updateAccount + sync
```

Relevant constraints in the current code:

- `lib/main.dart` renders `_Bootstrap` first and only builds `Pocket2FA`/`HomePage` after encrypted
  storage and desktop window geometry finish initializing, so a share can arrive before any Dart
  intake handler exists.
- `HomePage` owns the selected server (`HomeServerManager`), updates the account list
  (`updateAccount`) and triggers a background sync after a scan; the new-code FAB is only shown
  when at least one server exists.
- `MainActivity` is a `FlutterFragmentActivity` with `launchMode="singleTop"` and
  `taskAffinity=""`, and already overrides `onActivityResult`.
- Android receives shared content as a temporary `content://` URI; the grant ends with the
  receiving component's lifecycle, so the bytes must be copied before processing.
- `desktop_drop` 0.9.2 requires Flutter 3.47.7 (the project's version) and releases provider or
  temporary files when the `onDrop` callback returns; file reads/copies must be awaited inside it.
- The repo has Android, Windows and Linux targets only; there is no iOS project.
- `flutter_zxing` decodes at full resolution with `maxSize: 4000`; the gallery screen and the new
  paths must use the same call so detection stays identical.

## Goals / Non-Goals

**Goals:**

- One intake contract and one processing path for both Android shares and desktop drops.
- Deterministic handling of cold start, warm start, locked storage, missing servers, and repeated
  arrivals.
- Bounded memory and disk use for untrusted input, with no leftover files.
- Keep gallery and camera behavior byte-for-byte equivalent to today.

**Non-Goals:**

- iOS share extension, text/URL sharing, clipboard paste, or "Open with" file associations.
- Multi-image batch creation, a confirmation/preview screen, or image cropping.
- Changes to OTP parsing, server upload, account editing, or the gallery picker.
- Background/headless processing: every intake brings the app UI to the foreground.

## Decisions

### Decision 1: Handle Android shares natively in `MainActivity`

Add `ACTION_SEND` and `ACTION_SEND_MULTIPLE` intent filters for `image/*` to the existing
activity, and implement the share lifecycle in `MainActivity.kt`:

- `onCreate` keeps a launch share intent pending; it is handled only after Dart signals readiness.
- `onNewIntent` calls `super`, `setIntent(intent)`, and handles the new intent immediately (or
  queues it if Dart is not ready).
- A single `MethodChannel` (`net.gmartin.pocket2fa/incoming_image`) is bidirectional:
  - Dart registers its handler and calls `clientReady`; native flushes any queued descriptor.
  - Native calls `sharedImage` with either an accepted descriptor
    (`{kind: 'image', path, mimeType, name}`) or a rejection
    (`{kind: 'rejected', reason: 'multiple' | 'unsupported' | 'tooLarge' | 'unreadable'}`).
- `EXTRA_STREAM` and its `ClipData`/`EXTRA_STREAM` list form are both read. A share with more than
  one stream is rejected before any file is copied; a share with none is `unsupported`.
- Copying runs on a single background executor, then the result is delivered on the UI thread.
  This keeps a 32 MiB copy off the main thread.
- The content is copied to `cacheDir/incoming_qr_android/<uuid>.<ext>`; the extension comes from
  the resolver MIME type, never from an untrusted display name. The copy enforces the size cap
  and is removed if the copy fails or the size is exceeded.
- `onCreate` deletes surviving files in `incoming_qr_android/` before handling a new launch
  intent. That directory is Android-owned, so Dart never deletes the whole directory and cannot
  race the launch share.

`receive_sharing_intent` was considered and rejected: it adds a dependency, recommends changing
the activity launch mode, and hides the exact copy/size/single-image rules this change needs.
The native implementation is small and keeps the existing `singleTop` behavior.

### Decision 2: Use `desktop_drop` for Windows/Linux drag-and-drop

Wrap the `HomePage` content in a `DropTarget` enabled only on Windows and Linux, with
`acceptedKinds: {DropItemKind.file}`. The target covers the whole accounts UI, not a small zone.

- `onWillAccept` is synchronous and only checks the preview: exactly one `DropFileItem` whose
  MIME type starts with `image/` or whose name has a common image extension. It cannot perform
  I/O, per the plugin contract.
- `onEnter`/`onLeave` drive a translucent overlay with a drop icon and a localized "Drop a QR
  image here" message. The overlay is ignorable (`IgnorePointer`) so it does not affect the drop
  hit test.
- `onDrop` validates the actual item list, then copies the single file into
  `cacheDir/incoming_qr_desktop/<uuid>.<ext>` with the same 32 MiB limit. The copy is awaited
  inside `onDrop` because the plugin releases transfer files when the callback returns. Processing
  starts only after the copy completes.
- More than one item, zero file items, or a non-image item produces the corresponding rejection
  without copying.

`super_drag_and_drop` and per-platform native code were considered. `desktop_drop` supports the
project's Flutter version, Windows and Linux, and has a small API; the alternatives add either
Rust/cargokit tooling or two native implementations for no extra requirement.

### Decision 3: Extract the scan call into a shared service

A new `QrImageScanner` service owns the single decoding call:

```dart
Future<String?> decodeFile(String path) async {
  final result = await zx.readBarcodeImagePathString(
    path,
    DecodeParams(
      tryHarder: true,
      tryInverted: true,
      tryRotate: true,
      tryDownscale: true,
      maxSize: 4000,
    ),
  );
  return result.isValid && (result.text?.isNotEmpty ?? false) ? result.text : null;
}
```

`ImageQrScannerScreen` calls it instead of duplicating the call, and the incoming-image processor
uses the same method. This is the mechanism that guarantees share/drop detection and gallery
detection cannot drift. Unreadable files are distinguished from images without a QR by checking
`Code.isValid` plus the plugin error, or by catching decode failures; the processor exposes
`unreadable` separately from `noQr`.

### Decision 4: A typed incoming-image processor, not a new screen

A new `IncomingImageProcessor` orchestrates one accepted file:

1. Decode with `QrImageScanner`.
2. Parse with `EntryCreationService.parseOtpAuthUrl` (passing the context so the existing parse
   error message is shown once).
3. Upload with `EntryCreationService.createEntryOnServer` when a server is configured, exactly as
   `ImageQrScannerScreen` does.
4. Return a typed outcome: `success(AccountEntry)`, `noQr`, `invalidQr`, `unreadable`, or
   `serverMissing`.

`HomePage` owns the UI response: a non-dismissible progress dialog while processing, the existing
`accountUpdated` confirmation on success, `HomeServerManager.updateAccount`, a background sync,
and one localized message per failure. `invalidQr` does not add a second snackbar because
`EntryCreationService` already reported it; this preserves existing behavior while avoiding
duplicate messages.

No new screen is introduced: the user chose immediate processing, and the progress dialog covers
the scan/upload latency without adding a navigation step.

### Decision 5: Queue in `HomePage` until the app is ready

`HomePage` keeps at most one pending descriptor and a processing flag:

- The channel handler is registered in `initState`; Android's `clientReady` flush handles
  cold-start delivery.
- If storage is locked, the descriptor stays pending. `_maybeFlushPendingIncomingImage()` is
  scheduled post-frame when `storage.isUnlocked` becomes true, and is also called from the
  `PinLockScreen.onUnlocked` callback and from `didChangeAppLifecycleState(resumed)`. This covers
  PIN, biometric and retry unlock paths without adding a new storage notification API.
- If servers are not loaded yet, the descriptor stays pending until `HomeServerManager` reports
  loaded servers; with no servers it is rejected with the "add a server" message.
- On Android, before processing a warm-start share, `Navigator.popUntil(route.isFirst)` returns
  to the accounts screen so the progress dialog and result are visible. If manage mode is active,
  it is exited first so the new account is immediately visible.
- The processing flag rejects a second intake while one is in progress with the "one image at a
  time" message and deletes the newer working copy.
- The working copy is deleted in a `finally` block for every outcome, including cancellation
  after a failed upload.

### Decision 6: A 32 MiB ceiling and app-private staging

Both intake paths cap the accepted file at 32 MiB. This is far above a 12 MP JPEG or a 4K
screenshot, while preventing a malicious or accidental huge file from filling cache or memory.
Combined with `maxSize: 4000`, the decoded RGB buffer stays bounded. Rejections happen before
decoding and before reading the rest of an oversized stream.

Android and desktop use separate staging directories so cleanup ownership is unambiguous:
`incoming_qr_android/` is cleaned by `MainActivity` at process start, `incoming_qr_desktop/` by
Dart during `HomePage` initialization. Both directories are under the app cache, never external
storage.

### Decision 7: Localize all new outcomes

Add keys to `app_en.arb`, `app_es.arb` and `app_fr.arb` for: one-image-only, unsupported file,
too large, unreadable, no server, processing indicator, busy intake, and the drop affordance.
Reuse `noQrInImage`, `errorParsingQr`, and `accountUpdated`. Regenerate localizations with
`flutter gen-l10n` and keep `untranslated_messages.txt` empty.

## Risks / Trade-offs

- **Main-thread copy on Android** → Copy on a background executor and post only the descriptor to
  the UI thread; keep the 32 MiB cap.
- **Duplicate delivery on cold start** → Keep one native pending intent, clear it after copying,
  and flush only on `clientReady`; the `onNewIntent` path never re-reads the launch intent.
- **File deleted before ZXing reads it** → Dart deletes only after the decode/upload completes;
  native never deletes a file it has handed to Dart. Startup cleanup runs only before a new launch
  intent is copied.
- **Share arrives while a form or dialog is open** → Warm-start shares pop to the accounts route
  before processing, so the result is never shown behind another screen. The open form is
  abandoned; this is consistent with the user explicitly choosing to share into the app.
- **Share arrives while locked** → No account is created until unlock; the pending descriptor is
  held in memory and the staging file is deleted after processing. A process death discards the
  pending image and the startup cleanup removes the file.
- **Multi-image share targets** → The app declares `SEND_MULTIPLE` so it can honor the requested
  "only one image" error instead of silently not appearing. Users who select several images get
  an explicit rejection rather than a partial import.
- **Desktop provider files** → `onDrop` copies before returning; not doing so would lose the file
  when the plugin releases provider access.
- **Desktop drop while a modal route is open** → The drop target sits under the modal barrier and
  will not receive the drop; the user can close the dialog and drop again. No special handling is
  added.
- **New dependency on `desktop_drop`** → It brings native code on Android too. Verify the APK
  still builds and, for releases, run the repository's F-Droid reproducible-build check because
  new native plugin code can affect reproducibility.
- **Size-limit constants duplicated** → Native and Dart each enforce 32 MiB; a comment in both
  places and a verification task keep them aligned.

## Migration Plan

No data, API, storage or permission migration. The feature is additive: remove the manifest
filters, the channel wiring, the drop target, the dependency and the new services to roll back.
A staged rollout is unnecessary; test builds can disable intake by not registering the drop target
or by removing the intent filters, without touching the gallery path.
