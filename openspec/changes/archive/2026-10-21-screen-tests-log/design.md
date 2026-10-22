# Design

## Context

See `proposal.md` - Why. `LogScreen` reads `LogService.instance` directly, so
tests seed the singleton before pumping and clear it in `setUp`/`tearDown`. The
screen has:

- an empty state;
- a `ValueListenableBuilder<int>` on `LogService.entryCount`;
- level-colored `_LogEntryTile` rows;
- a filter `PopupMenuButton<int>`;
- copy, share and clear app-bar actions;
- a scroll-to-bottom FAB.

`pumpApp` provides localization. The clipboard is mocked on
`SystemChannels.platform` as in the account-tile tests. The share action is not
exercised: it reaches `path_provider` and `share_plus`.

## Goals / Non-Goals

**Goals:**

- Cover the empty/list states and all four level badges.
- Cover filtering, copying and clearing.
- Cover the FAB with a scrollable list.
- Keep the tests deterministic and free of file/share plugins.

**Non-Goals:**

- Sharing/exporting the log file.
- Testing `LogService` internals (already covered).
- Exact colors, timestamps or pixel layout.
- Testing platform-specific share behavior.

## Decisions

### Seed the real LogService

In each test:

```dart
LogService.instance.enabled = true;
LogService.instance
  ..debug('debug message', name: 'DebugSource')
  ..info('info message', name: 'InfoSource')
  ..warning('warning message', name: 'WarnSource')
  ..error('error message', name: 'ErrorSource');
```

Clear and disable capture in `setUp`/`tearDown` through `resetLogService` plus
an explicit `enabled = true` when seeding. The screen should see the entries
immediately because it reads `entries` during build.

### Empty state and level rows

Pump `const LogScreen()` inside `pumpApp`. With no entries assert `logEmpty`.
Seed all four levels and assert their messages, source names and `DEBUG`,
`INFO`, `WARN`, `ERROR` badges. Do not assert the generated timestamp string.

### Filter through the popup menu

Tap the filter icon, pump, and select the `ERROR` item through the popup menu
(`find.text('ERROR').last` if the badge is also present). Pump and assert the
error message remains while the other messages disappear. Re-open the menu and
select All to restore the list.

### Copy with a platform-channel mock

Install a handler for `SystemChannels.platform`, capture `Clipboard.setData`
arguments, and return `null` for other methods. Tap the copy icon, pump, assert
the clipboard text contains the report header and a seeded message, and assert
the `logCopied` SnackBar. Reset the handler in `tearDown`; pump past the
SnackBar duration before ending.

### Clear confirmation

Tap the delete icon, assert the confirmation dialog, tap Cancel and verify the
entries remain. Repeat, confirm, pump, and assert the empty state. This covers
both dialog outcomes and the `setState` after clearing.

### FAB with many entries

Seed enough entries to overflow the list, pump, tap the scroll-to-bottom FAB and
pump 300 ms. The assertion is that the frame completes without exceptions; the
scroll controller's final position is private and not worth exposing.

### Share remains out of scope

The share icon is rendered by the app bar, but tapping it would reach
`LogService.exportToFile`, `path_provider` and `share_plus`. That behavior will
be tested with platform mocks in a later stage.

## Risks / Trade-offs

- **Global LogService state** → clear/disable it in both setup and teardown.
- **Clipboard channel is global** → reset the handler in `tearDown`.
- **SnackBar timer** → pump 2 seconds after asserting the copy message.
- **Filter menu and badge share text** → select the menu item by its popup
  ancestor or use the last match, then assert the filtered messages.
- **Lazy list** → seed only a few entries for content tests; use many only for
  the FAB test.
- **Dynamic timestamps** → assert messages/names/levels, never the clock string.
- **Share plugins** → do not tap Share.

## Migration Plan

Not applicable: test-only change. Rollback is deleting the new test and
restoring the previous baseline.

## Open Questions

None that affect scope. Exact coverage will be measured after the test runs.
