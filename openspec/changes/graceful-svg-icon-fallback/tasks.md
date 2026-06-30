## 1. Sync Service — Decouple success from icon status

- [ ] 1.1 In `lib/services/sync_service.dart`, change the sync success condition (line ~339) from `failed == 0` to `anyFetched == true` so icon download failures do not mark sync as failed
- [ ] 1.2 Update the sync result message to distinguish "Sync completed" (all ok), "Sync completed — X icon(s) unavailable" (some icons failed), and "Sync failed — network error" (no data fetched)
- [ ] 1.3 Add an `iconStatus` field to the result map (`'all_ok'`, `'partial'`, `'all_failed'`) for UI differentiation

## 2. Icon Cache Service — Verify error resilience

- [ ] 2.1 Review `lib/services/icon_cache_service.dart` error handling in `getIconBytes()` — confirm that download errors throw cleanly and are caught by the sync service caller
- [ ] 2.2 Review `getIconFile()` — confirm it never throws on path construction (defensive path sanitization)
- [ ] 2.3 Ensure no unhandled `StateError` or other throwables escape `getIconBytes()` to the batch `Future.wait()` in a way that would cancel sibling downloads

## 3. Account Tile UI — Harden SVG error paths

- [ ] 3.1 In `lib/widgets/account_tile_ui.dart`, wrap `_sanitizeSvg()` in a try-catch that returns the original content on error (so `SvgPicture.string` can attempt parsing and use its own `errorBuilder`)
- [ ] 3.2 Verify the `FutureBuilder` error path (`snapshot.hasError`) already covers `file.readAsString()` failures and file-not-found scenarios
- [ ] 3.3 Verify the `SvgPicture.string` `errorBuilder` callback is correctly wired for all `flutter_svg` parse failures
- [ ] 3.4 Confirm the PNG/raster `FileImage` try-catch fallback path works for corrupt image files

## 4. Verification

- [ ] 4.1 Manual test: Sync with a 2FAuth server that has an account with a known-bad SVG icon URL — verify sync reports success and the account shows a letter placeholder
- [ ] 4.2 Manual test: Delete a cached SVG icon file from disk, then view the account — verify letter placeholder is shown without crash
- [ ] 4.3 Manual test: Place a malformed SVG (e.g., truncated XML) in the icon cache — verify letter placeholder is shown without crash
- [ ] 4.4 Manual test: Normal sync with all valid icons — verify sync still reports success and icons display correctly
- [ ] 4.5 Code review: Verify no other callers of `sync_service.dart` rely on the old `success == (failed == 0)` semantics
