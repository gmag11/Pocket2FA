# Design

## Context

See `proposal.md` - Why. Relevant current state:

- `AccountList` builds `AccountTile` (which delegates to `AccountTileTOTP` or `AccountTileHOTP`) and passes an `onEdit` callback for every account, based only on whether `HomeScreen` supplied one.
- Both tile variants render an edit `IconButton` in manage mode, enabled whenever `onEdit` is non-null.
- `HomeScreen._editAccount` pushes `AdvancedFormScreen` with the entry; the form assumes every existing entry is editable and falls back to returning a locally modified entry when the server rejects the update (403).
- `AccountEntry.isBorrowed` is parsed from `is_borrowed` and persisted, so the distinction is available in every UI layer (introduced by `fix-shared-account-otp`).
- 2FAuth authorizes `update`, `delete` and group assignment only for the owner, so no partial server-side edit of a borrowed account is possible.

## Goals / Non-Goals

**Goals:**

- Remove every user-reachable path into the edit form for borrowed accounts.
- Prevent borrowed accounts from being selected or processed by the deletion flow, including stale local tombstones.
- Make borrowed accounts recognizable at a glance with an indicator next to the username.
- Keep the change local to presentation/navigation and sync bookkeeping; no new server calls.
- Make the guards independent of how the tile was built, so future callers cannot bypass them.

**Non-Goals:**

- Local aliases or overrides for borrowed accounts (service/account/group).
- Changing sharing management or owned-account editing/deletion.
- Visually redesigning tiles beyond the shared indicator.

## Decisions

### Decision 1: Suppress the callback at the list boundary, not only hide the button

`AccountList` passes `onEdit: null` when `item.isBorrowed`. The tile variants render the edit control only when `onEdit != null`. This keeps the tile dumb and avoids a disabled-but-visible affordance.

**Alternative considered:** render the button disabled. Rejected: it still suggests an action that can never succeed and adds visual noise in manage mode.

### Decision 2: Use `isBorrowed` as the single read-only signal

The guard checks `AccountEntry.isBorrowed`, the flag parsed from `is_borrowed` and persisted across syncs/restarts. It deliberately does not use `seed.isEmpty`: that fallback exists for OTP routing, but for edit permissions the server-reported ownership flag is the authoritative signal and avoids misclassifying local entries.

**Alternative considered:** treat any empty-seed account as read-only. Rejected: it conflates an OTP-generation fallback with authorization and could hide editing for a transiently malformed owned account.

### Decision 3: Defense in depth at the navigation and form entry points

Even with the tile control gone, `HomeScreen._editAccount` returns early for borrowed accounts, and `AdvancedFormScreen` does not render an editable form when its existing entry is borrowed. This protects future callers (deep links, tests, new tile types) and guarantees no locally modified unsynced copy can be produced.

**Alternative considered:** rely only on hiding the button. Rejected: a single missed call site would reintroduce the bug silently.

### Decision 4: Block deletion at selection, operation and sync-retry layers

The delete flow is selection-driven: `AccountList` forwards `onToggleAccountSelection` to the tile checkbox, and `HomeManageMode.deleteSelectedAccounts` marks every selected id `deleted: true, synchronized: false` before calling the API. The design blocks it at three points:

1. `AccountList` passes no selection callback for borrowed accounts, and both tile variants omit the checkbox entirely, so there is no selection control to confuse the user and the tile tap does nothing in manage mode.
2. `HomeManageMode` ignores borrowed ids when building the deletion set (defense against a stale selection) and only marks/queues owned accounts.
3. `SyncService` ignores pending deletions whose account is borrowed and does not filter the fetched borrowed account out of the synchronized list. This repairs tombstones created by older builds: the next sync replaces the local entry with the server copy and stops retrying a deletion that always returns 403.

**Alternative considered:** only filter ids in `deleteSelectedAccounts`. Rejected: the stale-tombstone path in `SyncService` would keep retrying and the shared account would remain hidden locally.

### Decision 5: Reusable shared indicator with localized tooltip

Add `AccountTileUi.buildSharedIndicator(item)` returning an `Icon`/`Tooltip` when `item.isBorrowed`, or an empty box otherwise. Both TOTP and HOTP tiles place it in the username row immediately before the account text, so it appears in normal and manage mode with no layout duplication. The tooltip text is a new ARB key (`sharedAccount`) in en/es/fr, so the icon is not color- or icon-only semantics for accessibility.

Icon choice: `Icons.people_outline` at the username's font scale, tinted with the secondary text color. It denotes "shared with people" without implying an action, unlike `Icons.share`.

**Alternative considered:** badge over the avatar or a chip next to the service name. Rejected: the username row is where the rest of the account metadata already lives, and a chip would compete with the OTP code and progress dots.

## Risks / Trade-offs

- **Borrowed flag missing on data synced by an older app version** → those entries are treated as owned until the next sync refreshes them; acceptable, and `fix-shared-account-otp` persists the flag going forward.
- **Duplicate guards drift over time** → the checks are one-liners against a single model property; the spec scenarios make them explicit.
- **Stale deleted marker cannot be distinguished from an owned one if the flag is absent** → after the next sync the server copy restores `is_borrowed`, and the deletion is skipped from then on.
- **No local customization for shared accounts** → intentional, because the server cannot persist it; a future local-override feature would need its own change.
