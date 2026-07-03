## 1. Dependency setup

- [x] 1.1 Add `window_manager` package to `pubspec.yaml` (desktop-compatible version) and run `flutter pub get`
- [x] 1.2 Confirm `window_manager` builds successfully on Windows and Linux (`flutter build windows`/`flutter build linux`) — confirmed on Windows (release build); Linux still pending

## 2. Window geometry service

- [x] 2.1 Create `lib/services/window_geometry_service.dart` with load/save/restore/clamp logic
- [x] 2.2 Implement reading/writing `window_x`, `window_y`, `window_width`, `window_height`, `window_maximized` via `SharedPreferences`
- [x] 2.3 Implement clamping of restored bounds against the current virtual screen space (union of connected displays)
- [x] 2.4 Implement a `WindowListener` (or equivalent) that debounces (~500ms) move/resize events and persists geometry
- [x] 2.5 Persist geometry on window close (`onWindowClose`) as a final flush before the app exits

## 3. App startup integration

- [x] 3.1 In `lib/main.dart`, guard window-manager initialization behind `Platform.isWindows || Platform.isLinux`
- [x] 3.2 Initialize `window_manager` (`ensureInitialized`) and use `waitUntilReadyToShow` to create the window hidden
- [x] 3.3 Apply restored (or clamped/default) bounds and maximized state before showing the window
- [x] 3.4 Show the window only after bounds are applied, to avoid a visible jump

## 4. Native runner defaults

- [x] 4.1 `windows/runner/flutter_window.cpp`: removed the automatic `SetNextFrameCallback`/`ForceRedraw` show-on-first-frame logic so the window stays hidden until `window_manager` shows it (default origin/size in `main.cpp` untouched, still used as the first-run fallback)
- [x] 4.2 `linux/runner/my_application.cc`: removed the `first_frame_cb` signal handler that auto-showed the window; window is now realized but left hidden until `window_manager` shows it (default size untouched, still used as the first-run fallback)

## 5. Verification

- [x] 5.1 Manual test on Windows: resize/move window, restart app, verify position/size restored
- [x] 5.2 Manual test on Windows: maximize window, restart app, verify it reopens maximized
- [x] 5.3 Manual test on Linux: resize/move window, restart app, verify position/size restored
- [x] 5.4 Manual test: disconnect/simulate a monitor change so saved bounds would be off-screen, verify the window is clamped back on-screen instead of restoring off-screen
- [x] 5.5 Manual test: first run with no saved geometry still opens at the existing default size/position
- [x] 5.6 Verify Android build is unaffected (no window_manager calls invoked, app behaves as before)
