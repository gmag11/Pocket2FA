# Design

## Context

See `proposal.md` — Why. The relevant current flow is:

```
NewCodeScreen -> QrScannerScreen | ImageQrScannerScreen | AdvancedFormScreen
             -> best-effort POST /twofaccounts (EntryCreationService / ApiService)
             -> returns AccountEntry (synced with server id, or local with id == -1)
HomePage     -> HomeServerManager.updateAccount(result)   // lookup by server id
             -> background SyncService.forceSync()
```

`HomeServerManager.updateAccount` only replaces an account whose server `id` already exists in
`_servers` (`lib/screens/home_server_manager.dart:276-298`). A new entry has no such id, so the
result is dropped. The same is true even after a successful create, because the new server id
is not in the cached list; only the subsequent full sync makes it appear.

`SyncService` already has the building blocks for deferred creation:

- `forceSync` runs `_deletePendingAccounts`, `_uploadPendingAccounts`, `_updatePendingAccounts`,
  then fetches `groups` and `twofaccounts?withSecret=true`.
- `_uploadPendingAccounts` selects accounts with `id == -1 && synchronized == false` and calls
  `createAccountFromEntry`, replacing the local entry with the server response.
- If neither groups nor accounts can be fetched, `forceSync` returns before replacing local
  data, so cached entries survive a failed sync.
- Pending accounts are only retried when a sync is triggered. Sync-on-open is enabled by
  default, but auto-sync is opt-in and users can disable sync-on-open, so an offline-created
  entry may never be retried.

Constraints that shape the approach:

- `HomePage` only exposes account creation when at least one server exists, so every created
  entry belongs to the selected server.
- `AccountEntry.id` is an `int`, and the account list, selection, and manage mode use it as
  the identity. `AccountTile` already renders a pending badge for `synchronized == false`.
- Owned accounts generate codes locally from `seed`; borrowed accounts (`isBorrowed`) or
  accounts with an empty seed fetch codes from the server and must keep that behavior.
- The app has no connectivity plugin. Existing sync triggers are startup (if sync-on-open),
  foreground resume (if sync-on-open), optional auto-sync timer, pull-to-refresh, manual sync,
  and exiting manage mode.
- There is no test suite in the repository; verification is manual plus `flutter analyze` and
  platform builds.

## Goals / Non-Goals

**Goals:**

- Make the creation result the source of truth for the UI: insert it and persist it before any
  further network work, regardless of whether it is synchronized.
- Give each pending account a stable local identity so multiple offline creations behave like
  independent accounts.
- Retry pending uploads automatically and independently of user sync preferences.
- Reconcile a pending entry with its server record without losing the local secret or creating
  duplicates.
- Prevent a full sync from erasing entries that are still pending upload.

**Non-Goals:**

- Replacing the existing creation screens or centralizing all creation into one coordinator.
  The current best-effort immediate upload stays.
- Offline editing/deletion semantics beyond removal of never-uploaded entries.
- Multi-device conflict resolution, server-side idempotency, or deduplication of a creation
  request whose response was lost after the server committed it.
- Background execution while the app is terminated, push notifications, or a new connectivity
  dependency.
- Changing the 2FAuth API or local storage format beyond storing negative ids for pending
  entries.

## Decisions

### Decision 1: Insert creation results through a dedicated add path

Add a `HomeServerManager` operation for creation results, separate from `updateAccount`:

- If the entry has a positive server id and an account with that id exists, replace it.
- If it has a positive server id and no match exists, append it (this covers a create that was
  accepted during the creation flow).
- If it has a non-positive id, it is a local-only entry: mark it unsynchronized, assign a unique
  temporary id, and append it.
- Rebuild `currentItems`, notify listeners immediately, then persist the server list and await
  the write before scheduling uploads.

`updateAccount` keeps its current edit semantics (replace by server id, do nothing if absent),
so an edit can never accidentally insert a duplicate. Why not change `updateAccount` itself to
insert on a missing id? Because it is also used by the edit flow, where a missing id means stale
state rather than a new account.

### Decision 2: Use unique negative ids for local-only entries

The temporary id is the smallest negative value already present on that server minus one
(`-1` when there are no pending entries). It is stored in the existing `id` field, so
`toMap`/`fromMap`, selection sets, widget keys, and the existing pending badge continue to work
without a model migration.

Why not keep `-1` for every pending entry: the grid uses `ValueKey(item.id)` and manage-mode
selection uses `Set<int>`; several pending entries would share a key and be selected together.
Why not add a separate string `localId`: it would require changing the identity used by the
list, selection, edit, and delete paths for a problem that a per-server negative id already
solves. On load, duplicate non-positive ids from older stored data are normalized to unique
negatives so the invariant also holds for legacy pending entries.

Pending detection becomes `id <= 0 && !synchronized && !deleted`, matching both the new ids and
legacy `-1` entries.

### Decision 3: Keep the creation-time upload, but never depend on it

The scanners and the advanced form keep their existing best-effort `POST /twofaccounts`.
`HomePage` inserts whatever they return, synchronized or not. This preserves current logging,
error handling, and the fast online path while removing the dependency on upload success.

The alternative — removing uploads from all creation screens and letting a central coordinator
perform every create — would remove the pre-existing risk of a create whose response is lost
and then retried as a duplicate, but it touches three screens and changes the timing of error
reporting. It is a larger refactor than this change needs; the lost-response duplicate remains
a documented limitation.

### Decision 4: Targeted pending uploads and a bounded in-app retry loop

Expose a public `SyncService` operation that only uploads pending accounts for a server,
reusing `_uploadPendingAccounts`. It must not fetch groups or accounts, so retries are cheap
and cannot overwrite local data.

`HomeSyncManager` owns the retry schedule:

- After a creation result is inserted and persisted, attempt the pending upload immediately.
- On `HomePage` initialization after servers load, if pending entries exist, attempt an upload
  even when sync-on-open is disabled.
- On foreground resume, if pending entries exist, attempt an upload even when sync-on-open is
  disabled; keep the existing full-sync behavior otherwise.
- After a failed or partial upload, retry with a bounded backoff of 5 s, 15 s, 30 s, then
  60 s, repeating 60 s while pending entries remain.
- After any successful upload, reload servers from storage so the reconciled entries appear,
  and cancel the timer if nothing remains pending.
- Cancel the timer when the sync manager is disposed.
- Pause retries while manage mode is active to avoid replacing entries that are being selected
  or deleted; exiting manage mode already triggers a forced sync, which performs the upload.

Why not add `connectivity_plus`: an interface-change event does not prove the 2FAuth server is
reachable (captive portals, wrong network, server down), and the plugin adds native code to all
three targets. A short bounded retry plus the existing lifecycle and manual triggers reaches
the same state without a dependency. The trade-off is up to 60 s of latency after connectivity
returns while the app stays in the foreground; resume and user sync actions trigger immediately.

Why not rely on the existing auto-sync timer: it is disabled by default and skipped in manage
mode. Pending uploads must not depend on it.

### Decision 5: Reconcile in place and preserve local OTP material

When an upload succeeds, replace the entry identified by its temporary negative id with the
server entry, not by list position. Preserve local `seed`, `otpType`, `digits`, `algorithm`,
`period`, and `counter` when the server response omits them, and preserve `localIcon` and the
group name when the response lacks them. Mark the result synchronized.

This is needed because the create response is not guaranteed to include the secret (the list
endpoint only returns secrets with `withSecret=true`). Without the merge, an online create
could immediately lose the ability to generate a code until a full sync succeeds; a create
whose upload succeeds but whose following fetch fails would stay code-less indefinitely.

Use the same merge for `_updatePendingAccounts` so an edit response without a secret does not
erase the locally edited secret. This requires fixing `AccountEntry.copyWith`, which currently
drops `counter`.

### Decision 6: Merge pending entries into a fetched account list

After fetching accounts in `forceSync`, before persisting, append any stored local accounts that
are still unsynchronized and not deleted and whose id is not present in the fetched list. Keep
the fetched order and append pending entries at the end. This protects entries when the upload
failed but the account list was fetched successfully (for example a server-side validation
rejection, or a transient create failure while the read endpoint works).

Why not skip replacing the local list whenever a pending entry exists: that would also discard
legitimate server changes (other devices, group changes) for as long as one upload fails.

### Decision 7: Fix batch upload persistence and HOTP payloads

`_uploadPendingAccounts` currently builds each persisted server from the original immutable
`localServer`. After the first success, the next iteration writes a list that still contains
the original pending copy, undoing the earlier replacement. Keep a mutable working account
list, replace by temporary id after each success, and persist the working list after each
success. This also lets the operation report how many entries were uploaded.

`ApiService.createAccountFromEntry` sends `period` for HOTP (and `EntryCreationService` uses
`counter`), so a pending HOTP upload would lose its counter. Send `entry.counter ?? entry.period`
for HOTP, matching `updateAccountFromEntry` and the immediate-create payload.

### Decision 8: Remove never-uploaded entries locally

In manage mode, an account with `id <= 0` has never existed on the server. Deleting it removes
it from the local list immediately and does not mark it as a pending server deletion. Only
positive ids go through the tombstone/`DELETE /twofaccounts` path. `_deletePendingAccounts` also
drops legacy local tombstones with non-positive ids so they cannot accumulate.

## Risks / Trade-offs

- **Lost create response causes a duplicate** → If the server committed the create but the
  response was lost, retrying creates a second account. This is pre-existing and there is no
  idempotency key in the API; document it and rely on the user deleting the duplicate. A future
  change could reconcile by a client-generated marker if the server supports one.
- **Up to 60 s retry latency** → Acceptable without a connectivity dependency; startup,
  resume, manual sync, pull-to-refresh, and exiting manage mode all trigger sooner. Users see
  the pending badge and can pull to refresh.
- **Non-transient server rejection stays pending forever** → The entry remains visible with the
  pending indicator and retries at the capped interval. This preserves the user's data instead
  of silently dropping it; validation errors are logged. A future change could surface a
  permanent-failure state.
- **Negative ids are not understood by an older build** → An older build only uploads `id == -1`;
  entries stored with `-2` or lower would not sync after a downgrade. Sync pending entries before
  downgrading, or reinstall/upgrade again. No storage migration is required.
- **Retry timer during selection/deletion** → Paused in manage mode; exiting manage mode runs
  the existing forced sync.
- **Duplicate temporary ids from legacy data** → Normalized on load to unique negatives.
- **No automated tests** → Manual acceptance matrices are required for offline creation,
  restart, reconnection, multiple pending entries, HOTP, and reconciliation.

## Migration Plan

1. Existing local data needs no format change: `id` remains an integer and `synchronized`
   already exists.
2. On load, normalize any stored pending entries with non-positive ids that are duplicated to
   unique negatives; leave singleton `-1` entries untouched.
3. No server-side migration or API change is needed.
4. Rollback: the app can be downgraded, but pending entries with ids below `-1` will not be
   retried by the older build. No data is deleted; upgrading again resumes retries.

## Open Questions

None.
