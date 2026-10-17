# Proposal

## Why

GitHub issue #12 (open since June 2026) reports that Pocket2FA closes by itself as soon as one specific account's tile scrolls into view: 100% reproducible for that account, still reproducible after reinstalling, harmless in the 2FAuth web UI, and gone once the account is deleted and re-created (which changes its icon).

The earlier attempt at this bug — branch `fix/issue-12-concurrent-icon-io` (commit `381923a3`, never merged into `dev` or `main`, no PR, no tag, no 0.9.19 release) — hardened icon *writes*: it writes to a temp file and renames, and it checks that the file still exists before reading. That hypothesis no longer fits the evidence:

- A write race is intermittent and independent of the account. The report is deterministic and tied to one account.
- A reinstall wipes the icon cache. If the trigger were a locally-corrupted file, a reinstall would have fixed it. It did not, because the same bytes come back from the server.
- The same icon is fine in a browser. Browsers are far more tolerant (and downscale) than the image/vector decoders used at render time.

Two gaps therefore remain, and both can explain a process death rather than a Dart error:

1. **What the app does with the icon bytes at render time.** Raster icons are decoded at full resolution (`FileImage` with no `cacheWidth`/`resizeWidth`, `lib/widgets/account_tile_ui.dart:74-79`), and SVG icons are read as a full string and compiled (`:50-71`) with no size budget. An oversized icon or a very large/complex SVG can exhaust memory and have the process killed by the OS — a failure that no `errorBuilder`, `FutureBuilder` error path or `PlatformDispatcher.onError` handler can observe. The app "disappearing" with no red screen, no dialog and no Dart log is exactly this class of failure.
2. **Cache integrity.** The "atomic" write is not atomic: the temp path is a fixed `'${file.path}.tmp'` (`lib/services/icon_cache_service.dart:53`) and several accounts can share one icon file (2FAuth reuses icon files, and sync downloads with `concurrency = 4`), so two tasks can write the **same** temp file and publish a truncated icon. The read path never validates what it finds on disk (`:36-42`), nothing evicts a bad icon when rendering fails, and `evict()`/`clearAll()` are unreachable dead code — so a user cannot clear the icon cache except by reinstalling.

While investigating, the same class of problem surfaced in OTP generation: an account with an unusual parameter can leave its tile permanently broken (see the new `otp-parameter-guards` capability).

## What Changes

- **Icon cache writes**: use a unique temp name per download, and coalesce concurrent downloads of the same (server, icon) pair so an icon shared by several accounts is fetched and written once.
- **Icon size and shape budget**: cap what is downloaded, cap what is accepted from cache, and size-check before handing bytes to a decoder. Oversized or non-image content is rejected and never rendered.
- **Render path**: decode raster icons downscaled to avatar size, read the icon file once per tile instead of recreating the future on every build, and keep every failure path on the letter placeholder.
- **Cache self-healing**: when an icon fails to render, discard the cached copy (so the next sync can refetch it) without retrying in a loop, and add a "clear icon cache" action in Settings using the existing `IconCacheService.clearAll()`.
- **OTP parameter guards**: treat a missing or non-positive `period` as 30, bound `digits`, handle an unknown `algorithm` and short digests (md5) without throwing, and make sure a generation failure always leaves a refresh scheduled instead of freezing the tile.
- Fold the still-valid parts of `fix/issue-12-concurrent-icon-io` into this change, and drop that branch.

## Capabilities

### New Capabilities
- `icon-render-robustness`: Icons are size-bounded, downloaded once per file, validated before rendering, decoded at display resolution, and can never take the process down or permanently poison the cache.
- `otp-parameter-guards`: Account parameters coming from the server or the local form can never make OTP generation throw or leave a tile without a code and without a scheduled refresh.

### Modified Capabilities
<!-- None: `icon-fallback-resilience` (from the archived 2026-07-01 change) was never synced into `openspec/specs/`, so there is no existing spec to amend; its requirements are restated and extended by `icon-render-robustness`. -->

## Impact

- **Affected code:** `lib/services/icon_cache_service.dart` (unique temp, in-flight dedup, size caps, validation on read), `lib/widgets/account_tile_ui.dart` (downscaled decode, single read, eviction on failure), `lib/services/sync_service.dart` (batch/duplicate handling around icon downloads), `lib/services/otp_service.dart` (parameter guards), `lib/screens/settings_screen.dart` + `lib/l10n/app_*.arb` (clear-cache action). Possibly `lib/models/account_entry.dart` if a per-account "icon invalid" marker is persisted.
- **Supersedes:** branch `fix/issue-12-concurrent-icon-io` (`381923a3`) — to be deleted once this lands.
- **No new dependencies, no permissions, no storage migration.** Existing cached icons are simply re-validated and, when they fail, discarded.
- **Verification:** the crash itself needs synthetic fixtures (truncated file, 0-byte file, 4096x4096 PNG, SVG with tens of thousands of paths) to be reproducible without access to the reporting user's server, plus a manual pass on a real device with logcat to confirm no OOM/native abort.
- **Open evidence:** the reporting user was asked for logcat and never provided it; the account's icon (name/size/dimensions) is the other missing piece. Both are wanted before closing issue #12.
