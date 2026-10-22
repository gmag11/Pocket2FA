# Design

## Context

See `proposal.md` - Why. `WindowGeometryService` is a singleton with stateful
tests: `_initializing`, `_debounce`, `_savedBounds`, `_closing` and a cached
`SharedPreferences`. The test host is Linux, so `isSupportedPlatform` is true
and `showWindow` takes the Linux re-apply branch.

## Goals / Non-Goals

**Goals:**

- Cover init/show, debounced save and the close handshake.
- Use mocked platform channels and shared preferences.
- Keep the test self-contained on the singleton.

**Non-Goals:**

- Wayland-specific behavior or display clamping.
- Multiple independent service instances.
- Real window manager behavior.

## Decisions

### One ordered test for the singleton

Because the service is a singleton, run one `testWidgets` sequence:

1. install `window_manager` channel handlers;
2. set empty shared preferences so `_resolveStartupBounds` returns defaults;
3. `await service.init()` and assert `ensureInitialized`, `setBounds`,
   `setPreventClose(true)` and `waitUntilReadyToShow`;
4. `await service.showWindow()` and assert `show`, `setBounds`, `focus`;
5. call `onWindowResize()`, pump 600 ms and assert the debounced save wrote
   width/height;
6. call `onWindowClose()`, pump and assert `setPreventClose(false)` and `close`.

The singleton's state is intentionally consumed in this order; no reset API is
added.

### Window manager replies

Return `false` for `isFullScreen`, `isMaximized` and `isMinimized`; return a
fixed bounds map for `getBounds`; return null for void methods. Record method
names in a list for assertions.

### Shared preferences

`SharedPreferences.setMockInitialValues({})` keeps the startup bounds at the
default. The debounced save writes `window_width`/`window_height`, which the
test can read back.

### Close handshake

`onWindowClose` is unawaited internally; call it and pump a short real/fake
duration so `_handleClose` can complete. The `_closing` guard is intentionally
not reset.

## Risks / Trade-offs

- **Singleton state** → a single ordered test; do not try to reset private state.
- **Unawaited close** → pump after invoking and assert the calls, not a returned
  future.
- **Timer debounce** → pump past 500 ms.
- **Platform channels** → reset handlers in teardown.
- **Wayland env** → the test host is treated as X11; do not assert Wayland.
- **Shared prefs global** → set mock values at the start.

## Migration Plan

Not applicable: test-only change. Rollback is deleting the new test and
restoring the previous baseline.

## Open Questions

None that affect scope. Exact coverage will be measured after the test runs.
