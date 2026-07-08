import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'log_service.dart';

/// Default window bounds used on first run, or whenever no saved geometry
/// is usable (e.g. it would land fully off-screen). Mirrors the previous
/// hardcoded defaults in `windows/runner/main.cpp` and
/// `linux/runner/my_application.cc`.
const Rect _defaultBounds = Rect.fromLTWH(10, 10, 1280, 720);

/// Minimum window dimension (logical pixels) accepted when restoring saved
/// geometry, to guard against a degenerate/corrupted saved size.
const double _minWindowDimension = 200;

/// Size (logical pixels) of the title-bar corner that must overlap a
/// connected display for saved bounds to be considered reachable.
const double _minVisibleMargin = 48;

/// Persists and restores the desktop window's position, size, and
/// maximized state across app restarts on Windows and Linux.
///
/// This is a no-op on any other platform (Android, iOS, web).
class WindowGeometryService with WindowListener {
  WindowGeometryService._();

  static final WindowGeometryService instance = WindowGeometryService._();

  static const _xKey = 'window_x';
  static const _yKey = 'window_y';
  static const _widthKey = 'window_width';
  static const _heightKey = 'window_height';
  static const _maximizedKey = 'window_maximized';

  static bool get isSupportedPlatform =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux);

  /// On Wayland, the compositor controls window position. Clients cannot
  /// query absolute position (`gtk_window_get_position` always returns
  /// 0,0) nor set it (`gtk_window_move` is a no-op). Only size and
  /// maximized state are saveable/restorable.
  static bool get _isWayland =>
      Platform.isLinux &&
      (Platform.environment['WAYLAND_DISPLAY'] != null ||
          Platform.environment['XDG_SESSION_TYPE'] == 'wayland');

  Timer? _debounce;

  /// Cached after the first load in [init]; reused on every save so closing
  /// the window never has to await a fresh `SharedPreferences.getInstance()`
  /// platform-channel round trip.
  SharedPreferences? _prefs;

  /// Saved during [init] so [showWindow] can re-apply them after the window
  /// is mapped. On Wayland, `gtk_window_resize`/`gtk_window_move` called
  /// before the window is mapped can be silently overridden by the
  /// compositor when it assigns the initial configure event.
  Rect? _savedBounds;
  bool _savedMaximized = false;

  /// Guards against saving spurious geometry events that fire while the
  /// window is being shown and re-positioned during startup. Without this,
  /// the compositor's initial configure event (which may have a different
  /// size/position than the saved bounds) would overwrite the correct
  /// saved values in SharedPreferences.
  bool _initializing = true;

  /// Initializes `window_manager` and restores the previous session's window
  /// geometry (clamped to the currently available screen space), but does
  /// NOT make the window visible yet — call [showWindow] for that once the
  /// first Flutter frame has actually been painted.
  ///
  /// Splitting "restore geometry" from "show" avoids a brief blank/black
  /// native window: the window stays hidden (as configured in the native
  /// runner, see `windows/runner/flutter_window.cpp`) while Dart-side
  /// startup work (e.g. opening encrypted storage) is still in flight.
  ///
  /// Must be called once, after `WidgetsFlutterBinding.ensureInitialized()`.
  /// Does nothing on non-desktop platforms.
  Future<void> init() async {
    if (!isSupportedPlatform) return;

    await windowManager.ensureInitialized();

    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    final bounds = await _resolveStartupBounds(prefs);
    final maximized = prefs.getBool(_maximizedKey) ?? false;

    _savedBounds = bounds;
    _savedMaximized = maximized;

    windowManager.addListener(this);
    await windowManager.setPreventClose(true);

    await windowManager.waitUntilReadyToShow(null, () async {
      // Set bounds before showing on all platforms. On Windows this works
      // reliably (SetWindowPos operates on hidden windows). On X11 this
      // usually works too. On Wayland the compositor may override the
      // pre-map size, so [showWindow] re-applies bounds after mapping.
      await windowManager.setBounds(bounds);
      if (maximized) {
        await windowManager.maximize();
      }
    });
  }

  /// Reveals the window. Safe to call multiple times; no-op on non-desktop
  /// platforms. Should be called after the first Flutter frame has been
  /// rendered (e.g. via `WidgetsBinding.instance.addPostFrameCallback`) so
  /// the window never appears blank.
  Future<void> showWindow() async {
    if (!isSupportedPlatform) return;
    await windowManager.show();

    // On Linux — especially Wayland — the compositor may override the
    // window geometry when it maps the window, ignoring the pre-map
    // `gtk_window_resize`/`gtk_window_move` calls from [init]. Re-apply
    // the saved bounds (or re-maximize) after the window is visible so
    // the compositor's initial configure event doesn't win.
    //
    // On X11 this is a harmless no-op (same bounds, already applied).
    if (Platform.isLinux) {
      if (_savedMaximized) {
        await windowManager.maximize();
      } else if (_savedBounds != null) {
        // On Wayland, only the size portion of setBounds has any effect;
        // gtk_window_move is a no-op. On X11, both position and size work.
        await windowManager.setBounds(_savedBounds!);
      }
    }

    // Startup is complete: allow future geometry saves and discard any
    // spurious save that was scheduled during the show/re-apply sequence.
    _initializing = false;
    _debounce?.cancel();

    await windowManager.focus();
  }

  Future<Rect> _resolveStartupBounds(SharedPreferences prefs) async {
    final width = prefs.getDouble(_widthKey);
    final height = prefs.getDouble(_heightKey);
    if (width == null ||
        height == null ||
        width < _minWindowDimension ||
        height < _minWindowDimension) {
      return _defaultBounds;
    }

    // On Wayland, position is controlled by the compositor and cannot be
    // saved or restored. Use (0,0) as a placeholder; only the size matters.
    if (_isWayland) {
      return _clampSizeToDisplays(Rect.fromLTWH(0, 0, width, height));
    }

    final x = prefs.getDouble(_xKey);
    final y = prefs.getDouble(_yKey);
    if (x == null || y == null) {
      return _defaultBounds;
    }

    final saved = Rect.fromLTWH(x, y, width, height);
    return _clampToAvailableDisplays(saved);
  }

  /// Clamps the size of [saved] to the largest connected display, ignoring
  /// position. Used on Wayland where only size is restorable.
  Future<Rect> _clampSizeToDisplays(Rect saved) async {
    List<Display> displays;
    try {
      displays = await screenRetriever.getAllDisplays();
    } catch (e) {
      LogService.instance.warning(
        'Could not read displays, using saved size as-is: $e',
        name: 'WindowGeometryService',
      );
      return saved;
    }
    if (displays.isEmpty) return saved;

    final maxDisplay = displays.map((d) {
      final size = d.visibleSize ?? d.size;
      return Size(size.width, size.height);
    }).reduce((a, b) => (a.width * a.height) >= (b.width * b.height) ? a : b);

    final width = saved.width.clamp(_minWindowDimension, maxDisplay.width);
    final height = saved.height.clamp(_minWindowDimension, maxDisplay.height);

    return Rect.fromLTWH(saved.left, saved.top, width, height);
  }

  /// Clamps [saved] bounds so the window remains reachable on the currently
  /// connected displays. Falls back to [_defaultBounds] if the saved
  /// position isn't reachable on any connected display at all.
  Future<Rect> _clampToAvailableDisplays(Rect saved) async {
    List<Display> displays;
    try {
      displays = await screenRetriever.getAllDisplays();
    } catch (e) {
      LogService.instance.warning(
        'Could not read displays, using saved bounds as-is: $e',
        name: 'WindowGeometryService',
      );
      return saved;
    }
    if (displays.isEmpty) return saved;

    final displayRects = displays.map((d) {
      final position = d.visiblePosition ?? Offset.zero;
      final size = d.visibleSize ?? d.size;
      return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
    }).toList();

    // The window is considered "reachable" if at least a corner of its
    // title bar overlaps some connected display.
    final titleBarProbe = Rect.fromLTWH(
      saved.left,
      saved.top,
      _minVisibleMargin,
      _minVisibleMargin,
    );
    final isReachable = displayRects.any((r) => r.overlaps(titleBarProbe));
    if (!isReachable) {
      return _defaultBounds;
    }

    // Clamp size to the largest connected display so a window saved on a
    // bigger screen doesn't overflow a smaller one.
    final maxDisplay = displayRects.reduce(
      (a, b) => (a.width * a.height) >= (b.width * b.height) ? a : b,
    );
    final width = saved.width.clamp(_minWindowDimension, maxDisplay.width);
    final height = saved.height.clamp(_minWindowDimension, maxDisplay.height);

    // Clamp position to the union of all display bounds.
    final unionLeft = displayRects.map((r) => r.left).reduce(min);
    final unionTop = displayRects.map((r) => r.top).reduce(min);
    final unionRight = displayRects.map((r) => r.right).reduce(max);
    final unionBottom = displayRects.map((r) => r.bottom).reduce(max);

    final x = saved.left.clamp(unionLeft, unionRight - _minVisibleMargin);
    final y = saved.top.clamp(unionTop, unionBottom - _minVisibleMargin);

    return Rect.fromLTWH(x, y, width, height);
  }

  void _scheduleSave() {
    // Ignore geometry events that fire while the window is being shown
    // and re-positioned during startup. On Wayland, the compositor's
    // initial configure event carries a size/position that may differ
    // from the saved bounds; saving it would overwrite the correct
    // values in SharedPreferences.
    if (_initializing) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _saveCurrentBounds);
  }

  Future<void> _saveCurrentBounds() async {
    try {
      final maximized = await windowManager.isMaximized();
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      _prefs = prefs;
      if (!maximized) {
        final bounds = await windowManager.getBounds();
        await prefs.setDouble(_widthKey, bounds.width);
        await prefs.setDouble(_heightKey, bounds.height);
        // On Wayland, position is always (0,0) — gtk_window_get_position
        // returns origin because the compositor controls placement.
        // Don't save it; it would overwrite valid saved values with zeros.
        if (!_isWayland) {
          await prefs.setDouble(_xKey, bounds.left);
          await prefs.setDouble(_yKey, bounds.top);
        }
      }
      await prefs.setBool(_maximizedKey, maximized);
    } catch (e) {
      // Best-effort persistence only; ignore platform-channel failures
      // (e.g. during shutdown).
      LogService.instance.warning(
        'Failed to persist window geometry: $e',
        name: 'WindowGeometryService',
      );
    }
  }

  // window_manager emits `onWindowResize`/`onWindowMove` continuously on all
  // platforms, and the one-shot `onWindowResized`/`onWindowMoved` only on
  // Windows/macOS. Hooking both keeps Linux and Windows covered; the
  // debounce coalesces any duplicate calls.
  @override
  void onWindowResize() => _scheduleSave();

  @override
  void onWindowResized() => _scheduleSave();

  @override
  void onWindowMove() => _scheduleSave();

  @override
  void onWindowMoved() => _scheduleSave();

  @override
  void onWindowMaximize() => _scheduleSave();

  @override
  void onWindowUnmaximize() => _scheduleSave();

  /// Guards against re-entering the close flow: once we disable
  /// `preventClose` and let the OS close the window for real, window_manager
  /// re-emits a `close` event for that second, non-intercepted WM_CLOSE.
  bool _closing = false;

  @override
  void onWindowClose() {
    if (_closing) return;
    _closing = true;
    _debounce?.cancel();
    unawaited(_handleClose());
  }

  Future<void> _handleClose() async {
    final stopwatch = Stopwatch()..start();
    // Bound the save step so a slow/stuck platform-channel call never delays
    // shutdown by more than ~500ms.
    try {
      await _saveCurrentBounds().timeout(const Duration(milliseconds: 500));
    } on TimeoutException {
      debugPrint(
        '[WindowGeometryService] Saving window geometry timed out after '
        '${stopwatch.elapsedMilliseconds}ms, closing anyway.',
      );
    }
    debugPrint(
      '[WindowGeometryService] Save took ${stopwatch.elapsedMilliseconds}ms, '
      'letting the window close normally...',
    );
    // Disable prevent-close and let the OS perform its normal close
    // (DestroyWindow/WM_DESTROY on Windows, gtk_widget_destroy on Linux),
    // instead of `destroy()`. On Windows, `destroy()` only posts WM_QUIT and
    // skips the window's own destroy sequence entirely, so the Flutter
    // engine/GPU surface never get a chance to tear down cleanly -- the OS
    // then has to force-unload them during raw process exit, which is what
    // caused the several-second delay before the process actually died.
    await windowManager.setPreventClose(false);
    await windowManager.close();
    debugPrint(
      '[WindowGeometryService] close() returned after '
      '${stopwatch.elapsedMilliseconds}ms total.',
    );
  }
}
