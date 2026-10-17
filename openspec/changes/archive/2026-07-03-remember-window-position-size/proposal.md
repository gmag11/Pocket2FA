## Why

On Windows and Linux, Pocket2FA always launches at a fixed window position (10, 10) and fixed size (1280×720), values hardcoded in the native runner entry points (`windows/runner/main.cpp` and `linux/runner/my_application.cc`). Every other desktop application on these platforms remembers where the user left its window. A user has requested this behavior; not persisting window geometry across restarts is a recurring desktop UX papercut, especially for users who resize/reposition the window to fit a specific monitor layout or multi-monitor setup.

## What Changes

- Add the `window_manager` plugin (or equivalent) to enable Flutter-side control over window position and size on desktop platforms.
- On app startup (desktop only), restore the window to the position and size saved from the previous session, if available; otherwise fall back to the current default (1280×720, centered or at a sane default position).
- On window move/resize (debounced) and on app close, persist the current window bounds (x, y, width, height) and maximized state to local storage.
- Remove the hardcoded fixed origin/size from the native Windows and Linux runners in favor of Flutter-side restoration, or use them only as the first-run default.
- Clamp restored geometry to the currently available virtual screen space so the window never restores off-screen (e.g., after a monitor is disconnected).

## Capabilities

### New Capabilities
- `window-geometry-persistence`: Persist and restore the desktop window's position, size, and maximized state across app restarts on Windows and Linux.

### Modified Capabilities
<!-- None — no existing capability specs cover window/desktop behavior -->

## Impact

- **New files**: likely a small `lib/services/window_geometry_service.dart` (or similar) to own load/save/restore logic.
- **Modified files**: `lib/main.dart` (initialize window management before `runApp`), `windows/runner/main.cpp` (default size/origin becomes first-run fallback only), `linux/runner/my_application.cc` (same).
- **Dependencies**: adds a new pub package (e.g., `window_manager`) supporting Windows and Linux.
- **Storage**: a few small numeric values added to existing local settings storage (Hive/SharedPreferences) — no migration risk.
- **Platforms**: Windows and Linux only; Android/iOS are unaffected (no window chrome to manage).
- **Breaking changes**: None.
