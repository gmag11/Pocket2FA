## 1. Dependency setup

- [ ] 1.1 Add `window_manager` package to `pubspec.yaml` (desktop-compatible version) and run `flutter pub get`
- [ ] 1.2 Confirm `window_manager` builds successfully on Windows and Linux (`flutter build windows`/`flutter build linux`)

## 2. Window geometry service

- [ ] 2.1 Create `lib/services/window_geometry_service.dart` with load/save/restore/clamp logic
- [ ] 2.2 Implement reading/writing `window_x`, `window_y`, `window_width`, `window_height`, `window_maximized` via `SharedPreferences`
- [ ] 2.3 Implement clamping of restored bounds against the current virtual screen space (union of connected displays)
- [ ] 2.4 Implement a `WindowListener` (or equivalent) that debounces (~500ms) move/resize events and persists geometry
- [ ] 2.5 Persist geometry on window close (`onWindowClose`) as a final flush before the app exits

## 3. App startup integration

- [ ] 3.1 In `lib/main.dart`, guard window-manager initialization behind `Platform.isWindows || Platform.isLinux`
- [ ] 3.2 Initialize `window_manager` (`ensureInitialized`) and use `waitUntilReadyToShow` to create the window hidden
- [ ] 3.3 Apply restored (or clamped/default) bounds and maximized state before showing the window
- [ ] 3.4 Show the window only after bounds are applied, to avoid a visible jump

## 4. Native runner defaults

- [ ] 4.1 Confirm `windows/runner/main.cpp` default origin/size remain as the first-run fallback (no change needed unless conflicting with `window_manager`)
- [ ] 4.2 Confirm `linux/runner/my_application.cc` default size remains as the first-run fallback (no change needed unless conflicting with `window_manager`)

## 5. Verification

- [ ] 5.1 Manual test on Windows: resize/move window, restart app, verify position/size restored
- [ ] 5.2 Manual test on Windows: maximize window, restart app, verify it reopens maximized
- [ ] 5.3 Manual test on Linux: resize/move window, restart app, verify position/size restored
- [ ] 5.4 Manual test: disconnect/simulate a monitor change so saved bounds would be off-screen, verify the window is clamped back on-screen instead of restoring off-screen
- [ ] 5.5 Manual test: first run with no saved geometry still opens at the existing default size/position
- [ ] 5.6 Verify Android build is unaffected (no window_manager calls invoked, app behaves as before)
