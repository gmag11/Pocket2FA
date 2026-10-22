# Design

## Context

See `proposal.md` - Why. `SettingsScreen` is a `StatelessWidget` that listens to
`SettingsService` through an `AnimatedBuilder` and renders a `ListView` of
`ListTile`s. Each tile has a title and a trailing `Switch`, `SegmentedButton`,
`IconButton` or custom control. `pumpApp` supplies localization;
`FakeSettingsStorage` gives deterministic settings without Hive or plugins.

The screen also contains PIN callbacks that reach `SettingsStorage`, but this
stage does not open those dialogs. It renders the PIN row with a fake
`pinEnabled` value instead.

## Goals / Non-Goals

**Goals:**

- Cover the built screen, all non-PIN settings controls and navigation.
- Verify the settings values after taps, not just that taps do not throw.
- Keep the tests independent of secure storage, local auth and the network.

**Non-Goals:**

- Setting/changing/disabling a PIN (needs secure storage and dialogs).
- Covering `settings_storage.dart` class methods.
- Testing the internals of `LogScreen`; only assert that the navigation target
  appears.
- Exact colors, pixel positions or platform-specific animations.

## Decisions

### Use a tall surface so all tiles are built

`SettingsScreen` uses a `ListView`, so off-screen children may not be built.
Set `tester.view.physicalSize = const Size(1000, 1800)` and
`devicePixelRatio = 1.0`, and reset both in `addTearDown`. If a target is still
off-screen, use `scrollUntilVisible` instead of `find` by position.

### Locate each control through its tile title

Use:

```dart
Finder tile(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(ListTile));
```

Then `find.descendant(of: tile('...'), matching: find.byType(Switch))` or
`find.byType(IconButton)` gives the correct control even though the screen has
many switches. Do not use `find.byType(Switch).at(index)`.

### Build settings from the fake storage

Create `SettingsService(storage: FakeSettingsStorage(...))`, await
`reloadFromStorage()`, and pass the same instance to both `pumpApp` and
`SettingsScreen`. The harness's default values are:

- theme: system;
- format: spaced3, formatting enabled;
- biometrics: unsupported;
- PIN: disabled;
- hide OTPs: false;
- sync on open: true;
- automatic sync: false, 30 minutes;
- debug logging: false.

Tests change only the values they need and reset `LogService` in
`setUp`/`tearDown`.

### Assert values after taps

After tapping a switch or format button, `await tester.pump()` and assert the
corresponding `SettingsService` getter. This catches callbacks wired to the
wrong setting. For the interval, assert the text `30`, tap add, assert `31`,
tap remove and assert `30`.

### Theme selection

Tap the dark icon inside `SegmentedButton<ThemeMode>` and assert
`settings.themeMode == ThemeMode.dark`. Do not assert the rendered colors; the
screen's dark tile branch is covered separately by wrapping the child in
`Theme(data: ThemeData.dark())`.

### Debug logging and navigation

Enable debug logging through its tile switch, pump, and assert the
`View Diagnostic Log` button appears. Tap it, pump, and assert `find.byType(
LogScreen)` is present. `LogScreen` only reads `LogService`, so no network or
file plugin is reached by simply building it.

### PIN row without PIN flows

Build with `pinEnabled: true` and assert the `Change PIN` row is visible. Do not
tap its switch or icon; those callbacks open dialogs and secure-storage
operations that are outside this stage.

### Biometrics unavailable

With the fake's default `biometricsSupported: false`, assert the disabled
`Switch` and the `Biometrics not available` tooltip. This covers the honest
unsupported state without calling `local_auth`.

## Risks / Trade-offs

- **Lazy `ListView`** → tall surface first, `scrollUntilVisible` as a fallback.
- **Multiple identical switches** → resolve each through its `ListTile` title.
- **Async setters** → always `pump()` after taps and assert the service value,
  not only the widget's visual state.
- **LogService global state** → reset it around every test.
- **PIN dialogs/secure storage** → deliberately not opened.
- **Theme surfaces** → assert behavior, not exact colors; the dark case only
  checks that the screen renders with the dark theme.
- **Navigation target** → assert `LogScreen`, not its contents.

## Migration Plan

Not applicable: test-only change. Rollback is deleting the new test and
restoring the previous baseline.

## Open Questions

None that affect scope. Exact coverage will be measured after the test runs.
