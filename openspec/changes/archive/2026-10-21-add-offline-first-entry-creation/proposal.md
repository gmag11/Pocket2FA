# Proposal

## Why

Creating a new account (entry) currently behaves as if it only exists once the server has
accepted it. The creation forms return an `AccountEntry` with `id == -1` and
`synchronized == false` when the upload fails, and `HomePage` passes that result to
`HomeServerManager.updateAccount()`. That method searches for an existing account by server
`id`; a new entry has no server `id`, so the lookup fails and the entry is neither displayed
nor persisted (`lib/screens/home_server_manager.dart:276-298`). The same no-op happens even
when the upload succeeds, because the newly created server entry is not in the cached list
yet: it only becomes visible after the post-creation background sync downloads the list.

This has two user-visible consequences:

- **Offline creation silently loses the account.** The local entry already contains everything
  needed to generate codes (secret, type, digits, algorithm, period/counter), but it is
  discarded because the UI path is keyed on a server id.
- **Created accounts are not shown immediately.** Even with connectivity, the account
  appears only after a full sync, which can take seconds and depends on sync settings.

Pending uploads exist in `SyncService`, but they are only retried when a sync happens
(sync-on-open, auto-sync timer, pull-to-refresh, manual sync). If those settings are disabled,
an entry created while offline can stay pending indefinitely.

## What Changes

- **Insert new entries immediately, independently of the server.** When a creation flow
  returns an entry, add it to the selected server's account list and persist it before (or
  without waiting for) any network request. The account list must render it right away,
  including its OTP code when the local secret is available.
- **Support locally created entries with temporary ids.** Server-backed accounts keep their
  positive server ids. Entries that have not been uploaded get a unique negative local id so
  multiple pending entries do not collide in widget keys, selection, or deletion.
- **Treat every local-only entry as pending upload.** Pending-upload detection must use
  `id <= 0 && synchronized == false`, not the current `id == -1` special case.
- **Reconcile in place after upload.** When the server creates the account, replace the local
  entry at its position with the server entry, keep the local secret and OTP parameters when
  the server response omits them, and refresh the UI without requiring a separate full sync.
- **Preserve pending entries across full syncs.** A fetched account list must not erase local
  entries that are still pending upload; merge them back until they are accepted by the
  server.
- **Retry pending uploads automatically.** Attempt an upload immediately after creation, on
  app start and resume when pending entries exist, and through a bounded backoff timer while
  the app is running. Stop retrying when there is nothing pending. This must work even when
  sync-on-open and auto-sync are disabled.
- **Keep the pending state visible.** The existing `cloud_off` badge on unsynced tiles remains
  the indicator; no new confirmation screen or notification is introduced.
- **Fix adjacent correctness issues required by the above.** Persist each uploaded pending
  entry without the batch overwriting earlier successes, preserve `counter` in
  `AccountEntry.copyWith`, and delete a never-uploaded local entry locally instead of leaving
  an unsendable tombstone.

## Capabilities

### New Capabilities

- `offline-account-creation`: the lifecycle of an account from the moment a creation flow
  returns it — immediate local display and OTP generation, durable local storage, deferred
  server upload, reconciliation with the created server record, and automatic retry when
  connectivity returns.

### Modified Capabilities

<!-- No existing capability covers account creation or pending uploads. -->

## Impact

- **Affected code:**
  - `lib/screens/home_screen.dart` — creation result handling, startup/resume pending sync,
    reload after upload.
  - `lib/screens/home_server_manager.dart` — add/insert new accounts, temporary ids,
    persistence, replace pending entries in place.
  - `lib/screens/home_sync_manager.dart` — pending-upload retry scheduling and targeted upload
    attempts.
  - `lib/services/sync_service.dart` — public pending-upload entry point, batch persistence
    fix, merging pending local entries into fetched lists, OTP-field preservation.
  - `lib/services/entry_creation_service.dart` — preserve local OTP fields when the create
    response omits them.
  - `lib/models/account_entry.dart` — `counter` preservation in `copyWith`, optional merge
    helper.
  - `lib/screens/home_manage_mode.dart` — local-only deletion handling.
- **Data:** `AccountEntry.id` keeps its integer type; local-only entries use negative values.
  Existing stored data remains readable, and `id == -1` entries already written by older
  builds are treated as pending.
- **APIs:** no server API changes. The existing `POST /twofaccounts` flow is reused.
- **Dependencies:** none added. Retry uses in-app timers plus existing lifecycle and sync
  triggers; no background execution while the app is terminated and no connectivity plugin.
- **Platforms:** all current targets (Android, Linux, Windows) share the same Dart code path.
- **Verification:** there is no test directory in this repository, so acceptance relies on
  `flutter analyze`, builds for the available targets, and manual offline/online scenarios.
