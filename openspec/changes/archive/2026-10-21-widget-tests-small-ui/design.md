# Design

## Context

See `proposal.md` - Why. These five files are independent of the account tile
and of each other:

- `AboutDialogContent` is an `AlertDialog` with an asset image, localized text,
  two `url_launcher` links and a close button.
- `HomeSearchBar` owns no state; it uses an optional controller, focus node and
  change callback.
- `BottomBar` renders the server/account summary, reachability state and the
  manage-mode delete/done controls.
- `HomeHeaderAnimation` owns an `AnimationController`, a `ScrollController` and
  a scroll listener, but has no widget of its own.
- `ServerDetailScreen` is a small `StatefulWidget` that lists a server's
  accounts.

`pumpApp` provides localization and `SettingsService`; `serverConnectionFixture`
builds deterministic servers; `FakeSettingsStorage` keeps settings off the
platform. `TestVSync` is enough for the header animation.

## Goals / Non-Goals

**Goals:**

- Cover the rendered text, callbacks and state transitions of all five files.
- Cover the header's hide/show thresholds, viewport guard and disposal.
- Keep tests deterministic, with no network, URL-launcher calls or real plugins.

**Non-Goals:**

- Launching external URLs (the links are rendered and their callbacks are not
  exercised against `url_launcher`).
- Covering `home_screen.dart` integration or navigation; these tests pump the
  pieces directly.
- Testing exact colors or pixel positions.
- Changing the production widgets.

## Decisions

### About dialog: open it through a real dialog route

Pump a `Scaffold` with a button that calls `showDialog` and builds
`AboutDialogContent(appVersion: '1.2.3')`. This gives the close button a real
route to pop and lets the test verify the dialog disappears. Assert the app
title, the version line, both displayed links and the 2FAuth note. Do not tap
the links; that would reach `url_launcher`.

### Search bar: drive the controller and focus node

Pass a `TextEditingController`, `FocusNode` and `onChanged` callback. Enter
text and assert the callback and the clear button; tap clear and assert the
controller is empty, the callback receives `''` and the focus node has focus.
Render a second copy inside `Theme(data: ThemeData.dark())` to cover the dark
surface branch without asserting an exact color.

### Bottom bar: assert the summary and callback branches

Use `serverConnectionFixture(userEmail: 'user@example.test', url:
'https://example.test')`. Cover:

- no servers -> the `noServer` text;
- a selected server -> the `email - host` summary, and a missing id falling
  back to the first server;
- online/offline icons and tooltips;
- tapping the summary calls `onOpenSelector`.

For manage mode, assert Delete is disabled with no selected ids and enabled
with one, and that Done calls `onToggleManageMode`; tapping Delete calls
`onDeleteSelected`.

### Header animation: attach the controller to a short list

Create `HomeHeaderAnimation()`, call `initialize(const TestVSync())`, and pump a
`SizedBox(height: 200, child: ListView(controller: ...))` with enough rows to
scroll. Scrolling down changes the offset enough to hide the header; pump 500 ms
and assert the controller value dropped. Scrolling back up shows it again.

Use a second harness with height 400 (greater than four 70-pixel tiles) and
assert the header stays visible while scrolling. Dispose the animation at the
end of each test so the scroll listener and controllers are released.

### Server detail: assert title and list rows

Pump the screen with a `ServerConnection` containing two accounts and assert the
`Server: <name>` app bar plus both service/account rows. No callbacks fire in the
current screen, so `onChanged` is a no-op.

### Keep baseline measurement last

Run the full suite and coverage after all five files pass. The measured overall
value becomes the new floor.

## Risks / Trade-offs

- **Dialog close requires a Navigator route** -> open it from a real button, not
  by pumping the content directly.
- **Asset image in tests** -> the test asset bundle serves `assets/icon.png`; if
  it fails, assert the text content instead of the image.
- **Bottom bar URL parsing** -> fixture URLs always include a scheme and host.
- **Header scroll timing** -> pump the animation duration after dragging; do
  not use `pumpAndSettle` with a repeating animation (the header is finite, but
  explicit pumps keep it deterministic).
- **Header listeners after disposal** -> always call `dispose()` in a
  `addTearDown` and remove the widget tree before ending the test.
- **Manage-mode disabled styles** -> assert `onPressed == null` for Delete, not
  its color.
- **Text scaling/locale** -> use the English localization from `pumpApp`; do not
  assert translated strings from other locales.

## Migration Plan

Not applicable: test-only change. Rollback is deleting the new tests and
restoring the previous baseline.

## Open Questions

None that affect scope. Exact coverage will be measured after the tests run.
