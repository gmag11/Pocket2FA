# AGENTS.md

## Device and build rules

- **The Android phone always runs the RELEASE build.** Never install a debug APK on the
  device, and never replace the release app with a debug build for testing.
- **Never uninstall the app or clear its data without explicit permission.** Uninstalling
  removes the encrypted Hive box, preferences and secure-storage keys, so locally stored
  accounts, servers and PIN/biometric setup cannot be recovered.
- The release APK is signed with `android/app/keystore.jks` (or the CI release keystore).
  A debug-signed APK cannot update it; installing one over the release build fails with a
  signature mismatch.
- F-Droid split builds use `VercodeOperation: %c * 10 + ABI`, so the installed version code
  is not the same as `pubspec.yaml`'s build number. Check the package version before
  deciding whether an install is an upgrade or a downgrade.
- If the device needs a new build for testing, build and install the release variant
  (`flutter build apk --release --split-per-abi`) and ask before touching the device.

## Project notes

- Flutter 3.47.7, Dart 3.13.5. Targets: Android, Linux, Windows.
- `desktop_drop` is pinned to `^0.8.4`: 0.9.x requires `cross_file` 0.4, which the current
  `image_picker` ecosystem does not support yet.
- Run `flutter analyze`, `flutter gen-l10n` and the relevant `flutter build` before
  considering a change complete.
- OpenSpec changes live under `openspec/changes/`; follow the `spec-driven` workflow.
