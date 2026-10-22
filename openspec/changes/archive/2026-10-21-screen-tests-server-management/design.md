# Design

## Context

See `proposal.md` - Why. `AccountsScreen` reads and writes `SettingsStorage.box`
directly. `FakeSettingsStorage` provides an in-memory box, so tests can seed a
`servers` list and assert persisted changes without Hive.

`showServerAddEditDialog` is a dialog with name, URL and API-key fields, a
self-signed switch and Cancel/Add-or-Save actions. Validation calls
`ApiService.validateServer`, which creates its own `Dio`; this stage does not
test a successful remote validation.

## Goals / Non-Goals

**Goals:**

- Cover the unlocked server list, add/edit/delete and detail navigation.
- Cover the locked/storage-error surface.
- Cover dialog rendering, empty-URL validation, cancel and edit-mode behavior.
- Keep tests deterministic and free of Hive, secure storage and network.

**Non-Goals:**

- A successful `validateServer` request (it creates its own Dio; later stage).
- Certificate-error retry.
- Real PIN/biometric unlock.
- The green toast after a successful add/edit (requires validation to close the
  dialog).

## Decisions

### Seed the fake box

Construct:

```dart
FakeSettingsStorage(initialValues: {
  'servers': [server.toMap()],
})
```

and pass it to `AccountsScreen(storage: storage, settings: service)`. The
screen loads the list in `initState`; pump once after `pumpApp`.

### Avoid the automatic add dialog

With an empty server list, `AccountsScreen` opens the add dialog in a
post-frame callback. Always seed at least one server for list tests, or expect
the dialog when testing the empty state.

### Add/edit/delete flows

- Tap the FAB, assert the add dialog, then Cancel.
- Tap the edit icon, assert the edit title and prefilled fields, then Cancel.
- Tap the delete icon, Cancel once and assert the server remains; repeat,
  confirm and assert the list is empty.

The dialog's Cancel pops with `null`, so the screen leaves its list unchanged.
Delete confirmation is a separate `AlertDialog`; assert its title and confirm
text.

### Detail navigation

Tap the server `ListTile` and assert `ServerDetailScreen` appears. Its own
rendering is already covered by `server_detail_screen_test.dart`; this checks
the route wiring.

### Locked storage surface

Use `FakeSettingsStorage(unlocked: false, storageError: 'keyring unavailable')`
and a settings service with no PIN. `AccountsScreen` shows the local-data
protected title, the storage-unlock-failed message, the detail text and the
Retry button. Do not tap Retry: it would call the real `attemptUnlock`.

### Dialog tests directly

Open `showServerAddEditDialog` from a button so the Navigator has a route.
Assert the title, three text fields, self-signed switch and actions. Tap Add with
an empty URL and assert `URL required`; the dialog stays open and loading ends.

For edit mode, pass `initial: server`; tap the API-key field and assert its
`obscureText` becomes false and the text is cleared. Toggle the self-signed
switch and assert its value.

### No network validation

`ApiService.validateServer` builds a fresh `Dio` from the entered URL instead of
using the shared test harness. Testing a successful validation would require a
real loopback server; leave it for a later stage.

## Risks / Trade-offs

- **Auto-add dialog on empty storage** → seed a server for list tests.
- **Dialog text fields** → use `find.byType(TextField)` in field order
  (name, URL, API key) and assert labels.
- **Async dialog actions** → `pumpAndSettle` after opening/closing.
- **Secure storage** → never tap Retry or unlock actions.
- **Green toast timer** → not reached because successful validation is out of
  scope.
- **Delete persistence** → inspect the fake box values after confirmation if
  needed, but assert the rendered list first.

## Migration Plan

Not applicable: test-only change. Rollback is deleting the new tests and
restoring the previous baseline.

## Open Questions

None that affect scope. Exact coverage will be measured after the tests run.
