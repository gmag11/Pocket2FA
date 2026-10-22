# Proposal

## Why

`AccountsScreen` (144 executable lines) and `server_add_edit_dialog.dart` (119
lines) are both at 0% and form the server-management flow: list configured
servers, add/edit/delete them, open their account details and show the locked
storage state. This is the next self-contained screen after the entry chooser.

## What Changes

- Add widget tests for `AccountsScreen`:
  - loading servers from storage and rendering the list;
  - adding/editing/deleting a server through the dialog and the delete
    confirmation;
  - opening the server detail route;
  - the locked-storage error surface.
- Add widget tests for the add/edit dialog:
  - add-mode fields, cancel and empty-URL validation;
  - edit-mode initial values and API-key reveal/clear;
  - self-signed toggle.
- Raise `.coverage-baseline` to the measured overall value after the stage.

No production code, dependencies or public behavior changes.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

None. This is test-only work; the change declares `skip_specs: true`.

## Impact

- New tests under `test/widget/`.
- Reuses `pumpApp`, `FakeSettingsStorage`, `serverConnectionFixture` and
  `ApiTestHarness`; no new dependencies.
- `.coverage-baseline` rises from 45.52 to the measured value (expected around
  48-49%, not guaranteed).
- No `lib/` changes, so the release APK and Android install are unaffected.
- Certificate-error retry and real bio/PIN unlock remain for later stages.
