## Why

When a 2FAuth server account uses an SVG icon that fails to download or parse, the sync is marked as a partial failure (`success: false`) even though all account data (TOTP secrets, groups, metadata) was fetched successfully. This gives users a false impression that their sync failed, when the only issue is a cosmetic icon. Icon failures should be non-blocking — the account should show a letter placeholder and the sync should be treated as successful.

## What Changes

- **Sync success decoupled from icon status**: Icon download/processing failures no longer mark the sync as failed. Sync is considered successful as long as account data (entries + groups) was fetched.
- **SVG icon error resilience**: Any SVG icon that cannot be downloaded, read from disk, sanitized, or parsed by `flutter_svg` falls back gracefully to the letter-based placeholder avatar — without throwing unhandled errors or crashing the sync/app.
- **Sync result reporting**: The sync result distinguishes between "data sync failed" (accounts/groups not fetched) and "icon sync issues" (non-critical cosmetic failures), giving accurate feedback to the user.

## Capabilities

### New Capabilities

- `icon-fallback-resilience`: SVG and raster icon download/parse/read errors are fully handled at both sync time and render time, always falling back to a letter-based placeholder without blocking sync or crashing the UI.

### Modified Capabilities

_None_ — no existing spec-level behavior is changing beyond the resilience improvement documented above.

## Impact

- **`lib/services/sync_service.dart`**: Change sync success condition from `failed == 0` to `failed >= 0` (or remove icon failure from success calculation); update result message to differentiate data failures from icon-only issues.
- **`lib/widgets/account_tile_ui.dart`**: Verify and harden SVG loading/sanitization/parsing error paths; ensure all error paths return `fallbackAvatar()`.
- **`lib/services/icon_cache_service.dart`**: Verify error handling in `getIconBytes()` and `getIconFile()`; ensure no uncaught errors escape to callers.
- **`lib/models/account_entry.dart`**: Potentially add a `iconErrored` flag for UI differentiation (optional, may be deferred).
