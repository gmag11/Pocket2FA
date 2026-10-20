# Tasks

## 0. Decide scope with the reporter

- [ ] 0.1 Ask on GitHub issue #19 what the reporter expects after tapping the tile (plain launch vs. straight to the code list) and record the answer in `design.md` Open Questions
- [x] 0.2 Confirm the tile label wording for the three shipped languages (must stay short enough not to be truncated in the shade)

## 1. Native Quick Settings tile

- [ ] 1.1 Add `android/app/src/main/kotlin/net/gmartin/pocket2fa/QuickTileService.kt` extending `TileService`, with `onClick()` building a `MainActivity` intent (`FLAG_ACTIVITY_NEW_TASK`) and launching it wrapped in `unlockAndRun`
- [ ] 1.2 Implement the API branch inside `onClick()`: API >= 34 uses `PendingIntent.getActivity(..., FLAG_IMMUTABLE)` with `startActivityAndCollapse(pendingIntent)`; API < 34 uses the `Intent` overload
- [ ] 1.3 Declare the service in `android/app/src/main/AndroidManifest.xml` with `android:permission="android.permission.BIND_QUICK_SETTINGS_TILE"`, `android:exported="true"`, the `QS_TILE` intent filter, `android:icon` and `android:label`
- [ ] 1.4 Confirm the merged manifest for a release build contains the service exactly once and that no new `<uses-permission>` appears
- [ ] 1.5 Verify the tile does not keep the service alive: no `onStartListening` work, no timer, no `getQsTile()` manipulation beyond what is required

## 2. Icon and localized label

- [ ] 2.1 Add a monochrome `<vector>` drawable (e.g. `res/drawable/ic_qs_pocket2fa.xml`) sized for the tile, single path color, no background
- [ ] 2.2 Add `res/values/strings.xml` with `qs_tile_label` (English)
- [ ] 2.3 Add `res/values-es/strings.xml` and `res/values-fr/strings.xml` with the translated label
- [ ] 2.4 Add the Settings-facing strings for the add-tile entry to `lib/l10n/app_en.arb`, `app_es.arb` and `app_fr.arb`, and regenerate the localizations
- [ ] 2.5 Note in `design.md` that the Android label strings live outside the ARB pipeline so they are updated when a language is added

## 3. In-app add-tile entry point

- [ ] 3.1 In `MainActivity.kt`, register a `net.gmartin.pocket2fa/quick_tile` `MethodChannel` in `configureFlutterEngine` with a `requestAddTile` method; return a status (added / dispatched / unsupported) rather than throwing
- [ ] 3.2 Implement the handler with `requestAddTileService` on API 33+ (correct `ComponentName`, label and icon) and an `unsupported` result below API 33
- [ ] 3.3 Add a Dart-side wrapper (small service or helper) that calls the channel only when `Platform.isAndroid`, tolerates `MissingPluginException`, and exposes the status to the UI
- [ ] 3.4 Add the entry to `lib/screens/settings_screen.dart` via `_buildSettingTile(...)` with an Android-only visibility guard, showing the system prompt result or the manual instructions for older versions

## 4. Verification

- [ ] 4.1 `flutter analyze` passes with no new issues for the modified Dart files
- [ ] 4.2 Android debug and release builds succeed (`assembleDebug`, `assembleRelease`) proving the Kotlin and manifest changes compile
- [ ] 4.3 On a physical Android 14+ device: add the tile, tap it with the app closed, backgrounded and foregrounded, and confirm a single instance is brought to the front
- [ ] 4.4 On a device with a secure lock screen: tap the tile while locked and confirm the device credential is required before any code is visible
- [ ] 4.5 With the app's own lock enabled: open from a cold start via the tile and confirm the app lock screen still appears
- [ ] 4.6 Set the device to Spanish and French and confirm the tile label follows the language, and that the icon is tinted correctly in light and dark themes
- [ ] 4.7 On Android 12 or lower: confirm the tile still opens the app and the add-tile entry shows the manual instructions
- [ ] 4.8 Confirm Linux and Windows builds are unaffected and show no tile-related UI
