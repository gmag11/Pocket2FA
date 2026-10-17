# Proposal

## Why

Opening Pocket2FA to read a one-time password currently requires leaving the current app, finding the launcher icon and tapping it. GitHub issue #19 asks for a Quick Settings tile (like the user's previous 2FA app) so the app can be reached straight from the notification shade with a single tap.

Flutter has no API for Quick Settings tiles, so this has to be implemented in the Android host layer. That is cheap for Pocket2FA specifically: the project already owns a Kotlin `MainActivity`, ships Android + Linux + Windows (no iOS), and the tile's only job — launching the app — needs no Dart-side work at all.

## What Changes

- Add a Kotlin `TileService` under `android/app/src/main/kotlin/net/gmartin/pocket2fa/` and declare it in the main manifest with the `android.service.quicksettings.action.QS_TILE` intent filter and the `BIND_QUICK_SETTINGS_TILE` permission.
- Tapping the tile launches `MainActivity`: an already-running instance is brought to the foreground instead of a second task being created.
- Require the device to be unlocked before the app is shown (`unlockAndRun`), and never render one-time passwords on the tile surface itself, so codes cannot leak onto the lock screen.
- Provide a monochrome vector drawable for the tile icon and Android string resources for the tile label in the app's supported languages (English, Spanish, French).
- Add a Settings entry that helps the user add the tile: the system "add tile" prompt on Android 13+ (`requestAddTileService`), and short instructions on older versions.
- No new Dart dependency, no new runtime permission, no change to how codes are generated or displayed.

## Capabilities

### New Capabilities
- `quick-settings-tile`: An Android Quick Settings tile that opens Pocket2FA from the notification shade, without bypassing the device or the in-app lock and without exposing codes on the lock screen.

### Modified Capabilities
<!-- None: OTP generation, sync and the app's own lock flow are unchanged. -->

## Impact

- **Affected code:** new `android/app/src/main/kotlin/net/gmartin/pocket2fa/QuickTileService.kt`, new `android/app/src/main/res/drawable/ic_qs_pocket2fa.xml` and `android/app/src/main/res/values{,-es,-fr}/strings.xml`, additions to `android/app/src/main/AndroidManifest.xml`, and a new entry in `lib/screens/settings_screen.dart` (plus its `lib/l10n/app_*.arb` strings).
- **Platform:** Android-only. Linux and Windows builds are unaffected; the tile and the Settings entry are hidden everywhere else.
- **SDK constraints:** the project targets SDK 36 with `minSdk 24`. `startActivityAndCollapse(Intent)` throws on API 34+ when targeting 34+, so the tile must branch to the `PendingIntent` overload on API 34+; `requestAddTileService` needs an API 33 guard.
- **Verification:** the tile can only be validated manually on a physical device (or an emulator with SystemUI that exposes third-party tiles).
- **Open item:** what the app should show once the tile opens it (plain start screen vs. jumping to the code list) is pending the reporter's answer on issue #19; this proposal covers the plain-launch behavior only.
