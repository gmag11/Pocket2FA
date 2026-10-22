# Design

## Context

See `proposal.md` - Why. Current state:

- `AccountTileTOTP` is a `StatefulWidget` with `TickerProviderStateMixin`. It
  owns an `AccountTileOtpService`, an `AccountTileAnimations`, two reveal
  timers and a repeating animation. It has normal and manage-mode layouts.
- `AccountTileHOTP` owns an `AccountTileOtpService`, a reveal timer and a
  request timer. It requests HOTP codes from `ApiService` and has normal and
  manage-mode layouts.
- `AccountTileOtpService` is already covered (94.4%), so these tests can use
  the real service instead of mocking it.
- `pumpApp` supplies localization and `SettingsService` support.
  `FakeSettingsStorage` makes `hideOtps` deterministic.
- `ApiTestHarness` already serves `twofaccounts/<id>/otp` for HOTP tests.
- `withFixedTimeAsync` from `test/helpers/clock.dart` fixes the `clock`
  package, which `OtpService` uses to generate TOTP codes.
- `test/widget/account_tile_ui_test.dart` already covers dispatch and the
  shared presentation helpers; this stage only adds behavior.

## Goals / Non-Goals

**Goals:**

- Cover clipboard success, no-code and clipboard-failure SnackBars.
- Cover hidden-code reveal and the 10-second re-hide for TOTP and HOTP.
- Cover manage-mode selection, edit and borrowed-account branches.
- Cover HOTP request success, counter, offline state and 30-second clear.
- Cover wide-screen wrapping, `didUpdateWidget` and disposal.
- Keep tests deterministic and free of leaked timers and real network.

**Non-Goals:**

- Re-testing `AccountTileOtpService`, `AccountTileUi` or `AccountTileUtils`.
- Changing the tiles, `ApiService` or `SettingsService`.
- Testing pixel layout or animations frame by frame.
- Covering screens; they remain for later stages.

## Decisions

### One test file per tile

- `test/widget/account_tile_totp_test.dart`
- `test/widget/account_tile_hotp_test.dart`

Each file uses `pumpApp(tester, Scaffold(body: tile))` so SnackBars have a
`ScaffoldMessenger` and the tiles get normal layout constraints.

### Fix the clock for TOTP, not the animation

TOTP tests run the initial pump inside `withFixedTimeAsync(fixed, ...)` with
`fixed = utcFromUnixSeconds(59)` and the RFC seed
`GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ`, digits 8, period 30. That makes the current
code `94287082`; the next code is computed with `OtpService.generateOtp` at
`timeOffsetSeconds: 30`.

`AccountTileAnimations` uses `DateTime.now()` directly for progress, but the
tests assert text and callbacks, not animation values. Do not wrap the whole
test in a fixed clock just for animation timing.

### Never pumpAndSettle a TOTP tile

`AccountTileTOTP` starts a repeating `AnimationController`. `pumpAndSettle`
would spin forever. Use explicit `pump()` calls and, where needed,
`pump(const Duration(...))`. HOTP has no repeating animation, but explicit
pumps keep both files consistent.

### Mock the clipboard channel per test

Install a handler on `SystemChannels.platform` through
`TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger`, record
`Clipboard.setData` arguments, and return `null` for unrelated calls. The
failure test throws `PlatformException` for `Clipboard.setData`. Reset the
handler in `tearDown` so tests cannot leak into each other.

Clipboard assertions compare the `text` argument to digits without grouping
spaces, matching the production `replaceAll(RegExp(r'\s+'), '')`.

### Use the real OTP service and a real API harness

For HOTP, configure `ApiService.instance` with `serverConnectionFixture()`
before pumping and install `ApiTestHarness(api.dio)`. Register
`twofaccounts/<id>/otp` responses per test. `setUp`/`tearDown` close the API and
reset logging, following `account_tile_otp_service_test.dart`.

HOTP success uses `password: '123456'`, `counter: 7`; error uses an HTTP 500
reply. After tapping Generate, pump once for the future and once for the
resulting `setState`.

### Exercise timers with explicit durations

- Reveal: long-press the masked code, assert the visible code, then
  `pump(const Duration(seconds: 10))` and assert the mask is back.
- HOTP clear: after a code appears, `pump(const Duration(seconds: 30))` and
  assert the Generate button returns.
- TOTP timers are cancelled by replacing the tree with `const SizedBox()` and
  pumping before the test ends. SnackBar timers are advanced by a final
  `pump(const Duration(seconds: 2))` when a test asserts a SnackBar.

### Manage mode uses callbacks, not layout details

Pump the tile with `isManageMode: true`, `isSelected` and callbacks. Assert the
`Checkbox` value and tap it to verify `onToggleSelection`; tap the edit icon to
verify `onEdit`; for borrowed accounts assert there is no checkbox. Do not
assert pixel positions.

### Wide layout uses a surface size

Set `tester.binding.setSurfaceSize(const Size(1300, 800))`, pump, and assert a
`ConstrainedBox` with `maxWidth == 520` is present. Reset the surface size in
`tearDown`. This covers the `screenWidth > 1200` branches without goldens.

### `didUpdateWidget` uses the same widget type

Call `pumpApp` again with the same `SettingsService` and a different
`AccountEntry`; because the `MaterialApp`/`Scaffold`/tile types are stable, the
tile state is preserved and `didUpdateWidget` recreates its service. Assert the
new account text and that the test still disposes cleanly.

## Risks / Trade-offs

- **Repeating TOTP animation** → never use `pumpAndSettle`; dispose with
  `SizedBox` before the test ends.
- **Pending timers from reveal/HOTP** → advance them explicitly or replace the
  tree and pump; add a final `SizedBox` pump in every tile test.
- **Clipboard platform channel is global** → reset the handler in `tearDown`.
- **SnackBar timers outlive assertions** → pump past the 1.5-second duration.
- **HOTP request future** → pump after the tap; do not rely on
  `pumpAndSettle` while a SnackBar or timer is active.
- **Fixed clock only affects `clock.now()`** → assert TOTP text, not animation
  progress or `DateTime.now()`.
- **Wide layout has several `ConstrainedBox` widgets** → find by
  `constraints.maxWidth == 520`, not by type alone.
- **Manage-mode borrowed branch changes padding only** → assert the missing
  checkbox and the shared indicator, not exact offsets.
- **`setSurfaceSize` is binding-global** → reset it in `tearDown` even on
  failure.

## Migration Plan

Not applicable: test-only change. Rollback is deleting the two test files and
restoring the previous baseline.

## Open Questions

None that affect scope. Exact coverage will be measured after the tests run.
