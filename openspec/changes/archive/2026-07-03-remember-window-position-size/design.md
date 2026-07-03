## Context

Pocket2FA's desktop targets (Windows, Linux) currently hardcode the initial window origin and size in native runner code:
- `windows/runner/main.cpp`: `Win32Window::Point origin(10, 10); Win32Window::Size size(1280, 720);`
- `linux/runner/my_application.cc`: `gtk_window_set_default_size(window, 1280, 720);`

There is no Flutter-side window management today — no dependency like `window_manager` or `bitsdojo_window` is present in `pubspec.yaml`. The app's persisted settings (`SettingsService`/`SettingsStorage`) live in an encrypted Hive box that can be **locked** behind biometric authentication at startup (see `storage!.isUnlocked` check in `settings_service.dart`). Window geometry must be readable and restorable before/independently of that unlock flow, since resizing/positioning the window has nothing to do with the app's secret data.

## Goals / Non-Goals

**Goals:**
- Restore the last known window position, size, and maximized state on startup for Windows and Linux.
- Persist geometry changes (debounced) while the app runs, and on close, so the last state is always captured even if the app is killed abruptly (best-effort — no guarantee against hard crashes/power loss between the last debounce tick and the crash).
- Keep restored geometry usable: clamp to the currently connected virtual display area so the window is never restored fully off-screen.
- Keep the change additive and low-risk: no changes to mobile (Android/iOS) behavior.

**Non-Goals:**
- Multi-window support or per-monitor profile management.
- Restoring window geometry on any platform other than Windows and Linux (no macOS target exists in this repo).
- Changing how the encrypted settings box (Hive) is locked/unlocked for secret data.

## Decisions

### 1. Use the `window_manager` package for Flutter-side window control

**Choice**: Add `window_manager` (pub.dev) as the dependency for reading/writing window bounds and listening to move/resize events, rather than hand-rolling platform channels.

**Rationale**: `window_manager` already supports Windows and Linux (and macOS, unused here), exposes `getBounds()`/`setBounds()`, `isMaximized()`/`maximize()`, and a `WindowListener` for move/resize/close events. It's widely used and actively maintained, avoiding custom native C++/GTK code in the runners beyond removing the hardcoded defaults.

**Alternative considered**: `bitsdojo_window` — more focused on custom title bars, less on geometry persistence. Hand-written platform channels — much more code to maintain for marginal benefit.

### 2. Persist geometry via plain `shared_preferences`, not the encrypted `SettingsStorage` Hive box

**Choice**: Store `window_x`, `window_y`, `window_width`, `window_height`, `window_maximized` directly via `SharedPreferences`, independent of `SettingsService`/`SettingsStorage`.

**Rationale**: Window geometry is not sensitive data and must be available to restore the window immediately at startup, before any biometric unlock gate is resolved. Coupling it to the lockable Hive box would mean the window couldn't be resized/repositioned correctly until after unlock, or would require special-casing reads from a locked box.

**Alternative considered**: Add unlocked fields to the existing Hive box — rejected because `SettingsStorage` already special-cases "locked" reads to skip loading, which would complicate this narrow, unrelated concern.

### 3. New `WindowGeometryService` owns load/save/restore/clamp logic

**Choice**: A small dedicated service (not part of `SettingsService`) initializes `window_manager`, restores bounds on startup, and listens for move/resize/close to persist (debounced ~500ms) via `SharedPreferences`.

**Rationale**: Keeps window-chrome concerns separate from app settings/business logic, mirrors the existing pattern of single-purpose services (`LogService`, `IconCacheService`).

### 4. Restore-then-show pattern to avoid visual flicker

**Choice**: Create the window hidden (`windowManager.waitUntilReadyToShow`), apply saved bounds/maximized state, then show the window — instead of showing at the native default and jumping to the saved position after Flutter initializes.

**Rationale**: Avoids a visible "jump" from the hardcoded default position/size to the restored one, which would look broken.

### 5. Clamp restored bounds to available virtual screen space

**Choice**: Before applying saved bounds, clamp the rectangle so at least a minimal portion of the title bar remains within the union of connected display bounds (query via `window_manager`'s screen APIs or `dart:ui`'s `PlatformDispatcher.instance.displays`). If saved bounds are invalid/clamped to nothing usable, fall back to the original default (1280×720, centered).

**Rationale**: Prevents the classic "window opens off-screen because I unplugged my second monitor" bug.

### 6. Native runner defaults remain as first-run fallback

**Choice**: Keep `windows/runner/main.cpp` and `linux/runner/my_application.cc` defaults (1280×720 near top-left) unchanged as the value used before Flutter's `window_manager` restoration kicks in on first run (no saved prefs yet).

**Rationale**: Minimizes native code changes/risk; the Flutter-side restoration overrides these defaults immediately after startup once `window_manager` applies saved bounds.

## Risks / Trade-offs

- **[Low] Extra dependency (`window_manager`)** → Well-maintained, widely used package; scoped to desktop platforms only, no effect on mobile builds.
- **[Low] Debounce window loses last few pixels of a drag on abrupt crash** → Acceptable; also save on the window close event as a final flush.
- **[Low] Multi-monitor disconnect could still restore a partially off-screen window** → Mitigated by clamping logic in Decision 5; not a hard guarantee for all exotic display configurations.
- **[Low] Minor startup timing changes** (window created hidden, shown after bounds applied) → Should be imperceptible; verify no added startup delay during manual testing on both platforms.
