# Tasks

## 1. Shared QR image scan service

- [ ] 1.1 Add `lib/services/qr_image_scanner.dart` with a `decodeFile(String path)` method that performs the single `zx.readBarcodeImagePathString` call using `DecodeParams(tryHarder: true, tryInverted: true, tryRotate: true, tryDownscale: true, maxSize: 4000)` and returns the QR text or null; verify `flutter analyze` passes and `grep -rn "readBarcodeImagePathString" lib` matches only this service.
- [ ] 1.2 Refactor `lib/screens/image_qr_scanner_screen.dart` to call the service and keep its existing parse/upload/snackbar behavior; verify `grep -n "DecodeParams\|maxSize" lib/screens/image_qr_scanner_screen.dart` returns no matches and the screen still compiles with `flutter analyze`.
- [ ] 1.3 Manually scan the same gallery image on Android before and after the refactor and confirm the same QR content and account result; record the result in the change notes or PR description.

## 2. Incoming image processor and messages

- [ ] 2.1 Add `lib/services/incoming_image_processor.dart` with a typed outcome (`success`, `noQr`, `invalidQr`, `unreadable`, `serverMissing`) and a `process(path, serverHost, groups, context)` method that decodes with `QrImageScanner`, parses with `EntryCreationService.parseOtpAuthUrl`, and uploads with `createEntryOnServer`; treat the local unsynchronized entry returned when the upload fails as `success` so an unreachable server does not discard the account; verify `flutter analyze` passes and the processor contains no `BuildContext` usage beyond forwarding to the existing entry service.
- [ ] 2.2 Distinguish unreadable images from QR-less images: return `unreadable` when decoding throws or reports an invalid code with a plugin error, and `noQr` only when decoding succeeds but finds no barcode; verify by running both cases manually through a small debug call or the integrated UI and checking that the two different messages appear.
- [ ] 2.3 Add the new keys to `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb` and `lib/l10n/app_fr.arb` for single-image-only, unsupported file, too large (with the 32 MiB parameter), unreadable image, no server, processing, busy intake, and the drop affordance; run `flutter gen-l10n` and verify `untranslated_messages.txt` stays empty and `flutter analyze` passes.
- [ ] 2.4 Confirm the processor does not show a second message for `invalidQr` (the existing parser already reports it) and that secrets are not logged; verify with `grep -n "decoded URL" lib/services/entry_creation_service.dart` and an invalid-QR manual run showing exactly one error message.

## 3. Android share intake

- [ ] 3.1 Add `ACTION_SEND` and `ACTION_SEND_MULTIPLE` intent filters with `mimeType="image/*"` to the existing `MainActivity` in `android/app/src/main/AndroidManifest.xml`, keeping `launchMode="singleTop"`; verify with `flutter build apk --debug` and confirm Pocket2FA appears in the Android share sheet for a single image.
- [ ] 3.2 In `MainActivity.kt`, register the `net.gmartin.pocket2fa/incoming_image` method channel in `configureFlutterEngine`, keep a launch share intent pending until Dart calls `clientReady`, and handle `onNewIntent` by calling `setIntent` and delivering or queuing the new intent; verify a cold-start share and a warm-start share each reach Dart with `adb logcat` instrumentation or a temporary debug log.
- [ ] 3.3 Implement share extraction and staging in `MainActivity.kt`: read `EXTRA_STREAM` plus the stream list form, reject zero streams as `unsupported` and more than one as `multiple` without copying, copy a single `content://` image on a background executor to `cacheDir/incoming_qr_android/<uuid>.<ext>`, enforce the 32 MiB cap, and delete the partial file on failure or overflow; verify each rejection reason is emitted and that the accepted file exists before Dart receives it.
- [ ] 3.4 Clean `incoming_qr_android/` at process start before handling a new launch intent, and emit a descriptor with the copied path, MIME type and display name; verify a forced app kill with a staged file followed by a new launch leaves no stale file.
- [ ] 3.5 Manually test on an Android device: share one valid QR image from Gallery and from Files (cold start and warm start), share two images, share image content with no QR, and share an oversized image; verify the accepted cases process automatically and every rejected case shows the expected message with no account created.

## 4. Desktop drag-and-drop

- [ ] 4.1 Add `desktop_drop: ^0.9.2` to `pubspec.yaml` and run `flutter pub get`; verify the lockfile updates and `flutter build linux --debug` succeeds.
- [ ] 4.2 Wrap the `HomePage` content in a `DropTarget` enabled only when `Platform.isWindows || Platform.isLinux`, accept only `DropItemKind.file`, and reject zero files, multiple files and non-image items before copying; verify on Linux by dropping one image, two images, a text file and a non-file drag, and confirm only the single image case starts processing.
- [ ] 4.3 Implement the drag hover overlay with `onEnter`/`onLeave`, a drop icon and the localized drop message, marked `IgnorePointer`; verify the overlay appears on drag enter and disappears on leave and on drop.
- [ ] 4.4 Copy the single dropped file inside the awaited `onDrop` callback into `cacheDir/incoming_qr_desktop/<uuid>.<ext>` using `openRead`, enforcing the same 32 MiB cap, then hand the path to the intake coordinator; verify the file survives after the drop callback returns and that an oversized stream is aborted and removed.
- [ ] 4.5 Delete stale files from `incoming_qr_desktop/` during `HomePage` initialization; verify a leftover file is gone after an app restart and that a file staged during the current session is not removed.

## 5. HomePage intake coordination

- [ ] 5.1 Register the Android channel handler in `HomePage.initState`, call `clientReady` after registration, and keep at most one pending descriptor; verify a share delivered before the handler exists is flushed exactly once and does not create two accounts.
- [ ] 5.2 Implement the processing flow: when an image is accepted, exit manage mode, pop to the root route on Android, show a non-dismissible progress dialog, run `IncomingImageProcessor`, insert the result with `HomeServerManager.insertCreatedAccount`, show `accountUpdated`, call `HomeSyncManager.ensurePendingUploads()` so a locally pending entry is uploaded by the offline-first retry path, and delete the working copy in `finally`; verify one valid share adds the account once and removes the file, and that an unreachable server leaves it visible with the pending badge and uploads it exactly once after reconnection.
- [ ] 5.3 Map every failure outcome to its localized message (single image only, unsupported, too large, unreadable, no QR, parse error, no server) and reject a second intake while one is processing with the busy message; verify each case manually and confirm no account is added.
- [ ] 5.4 Gate processing on readiness: hold the descriptor while storage is locked, flush it after `PinLockScreen.onUnlocked`, `didChangeAppLifecycleState(resumed)` or the post-frame unlocked check, and hold it while servers are still loading; verify a share while PIN-locked processes only after unlock and exactly once.
- [ ] 5.5 Reject incoming images when no server is configured with the "add a server" message and create nothing; verify by removing all servers, sharing a valid QR image and confirming the message and unchanged server list.
- [ ] 5.6 Update the README feature/usage notes to mention sharing an image to the Android app and dropping one on the desktop app; verify the documented steps match the implemented behavior.

## 6. Integration verification and release checks

- [ ] 6.1 Run the full Android acceptance matrix in one session: cold/warm single share, multiple share, no QR, non-OTP QR, oversized file, locked start, no server, server unreachable during the share (pending upload and retry after reconnection), second share during processing, and gallery/camera regression; verify every outcome matches the specs and no account is duplicated.
- [ ] 6.2 Run the desktop acceptance matrix on Linux and Windows: single image, multiple files, non-image file, oversized file, no QR, non-OTP QR, locked start, no server, server unreachable during the drop, and gallery selection regression; verify every outcome matches the specs.
- [ ] 6.3 Run `flutter analyze`, `flutter gen-l10n`, `flutter build apk --split-per-abi`, `flutter build linux`, and a Windows build on a Windows host or CI; verify all succeed with no new analyzer warnings and `untranslated_messages.txt` remains empty.
- [ ] 6.4 Run the repository's F-Droid reproducible-build check for the split-per-ABI APKs after adding `desktop_drop`, following `.github/skills/fdroid-reproducible-build/SKILL.md`; verify the resulting APKs are byte-identical across the two build environments and record any new native-library flags needed.
- [ ] 6.5 Run `openspec validate add-qr-image-share-and-drop --strict` and verify the change passes with both capability deltas present.

## Workflow follow-up

- Archive the change after review, the acceptance matrices, and the reproducible-build check are complete.
- Verify the archived result with `openspec show add-qr-image-share-and-drop --type change` or the project's archive review step.
