## Context

Pocket2FA syncs TOTP/HOTP accounts from a 2FAuth server via its REST API. During sync, account icons (PNG, SVG, etc.) are downloaded from `{serverUrl}/storage/icons/{filename}` and cached to local disk. The `AccountEntry` model stores both the server-side `icon` filename and a local `localIcon` path.

At render time, `AccountTileUi.buildServiceAvatar()` reads the cached file, sanitizes SVGs (stripping percentage units unsupported by `flutter_svg`), and renders via `SvgPicture.string()` for SVGs or `FileImage` for raster formats. A letter-based `CircleAvatar` fallback is already implemented for all error paths in the widget.

**Current problem**: In `sync_service.dart` line 339, the sync success condition is `failed == 0`, where `failed` counts icon download failures. This means a single SVG icon that times out, returns 404, or produces a malformed response marks the entire sync as a failure — even though all account secrets and metadata were fetched and persisted correctly. The user sees "Sync completed with failures" and a red/error indicator, causing confusion and unnecessary re-sync attempts.

Additionally, while the UI error paths are well-covered, there is no defense at the sync level against SVG-specific issues (e.g., a very large SVG that causes OOM during sanitization if sanitization were moved to sync time, or an SVG with a `<!ENTITY>` bomb). These are currently low-risk because SVG content is not processed during sync, but the design should ensure this remains the case.

## Goals / Non-Goals

**Goals:**
- Decouple sync success from icon download/processing status — sync succeeds if accounts + groups are fetched
- Ensure every icon-related error path (download, disk read, sanitization, SVG parsing, raster decoding) falls back to the letter placeholder without crashing
- Provide accurate sync result feedback that distinguishes "data sync" from "icon issues"

**Non-Goals:**
- SVG-to-PNG conversion or server-side icon transcoding
- Retry logic for failed icon downloads (future enhancement)
- Icon format validation or size limits (can be added later)
- Changing the icon caching directory structure or naming convention
- Supporting additional icon formats beyond PNG/SVG

## Decisions

### Decision 1: Sync success = "accounts and groups fetched successfully"

**Choice**: Change the success condition in `sync_service.dart` from `failed == 0` to `anyFetched == true` (accounts or groups fetched). Icon download failures are tracked separately and reported in the result message but do not affect `success`.

**Rationale**: Icons are cosmetic. The core value of sync is TOTP/HOTP secrets, account names, and group associations. Losing those because an SVG icon couldn't download is the wrong trade-off. The user can always re-sync later to retry icon downloads.

**Alternatives considered**:
- *Keep `failed == 0` but add retry*: More complex, still blocks sync on transient icon server issues. Rejected.
- *Separate icon sync as a different operation*: Adds API surface and UI complexity. Rejected for this change (could be a future enhancement).

### Decision 2: Keep icon processing purely at render time

**Choice**: Do NOT add SVG sanitization or validation during sync. Sync only downloads raw bytes and writes to disk. All processing (sanitization, parsing) stays in the UI layer where `errorBuilder` and `FutureBuilder` already provide fallback paths.

**Rationale**: Moving processing to sync time would introduce new failure modes that could block sync. The current separation (sync = storage, UI = rendering) is correct. We just need to ensure the sync doesn't penalize icon failures.

**Alternatives considered**:
- *Validate SVG during sync*: Would catch bad SVGs early but adds sync-time processing risk and complexity. Rejected — let the UI handle it.

### Decision 3: Harden UI error paths with explicit try-catch wrapper

**Choice**: Wrap `_sanitizeSvg()` in its own try-catch that returns the original content on error (so `SvgPicture.string` can attempt parsing and use its own `errorBuilder`), and ensure `file.readAsString()` errors are caught by `FutureBuilder`.

**Rationale**: `_sanitizeSvg` uses a regex that should never throw, but defensive coding prevents edge cases (null bytes, encoding issues). The `FutureBuilder` already catches future errors via `snapshot.hasError`. This decision is about adding one extra safety layer.

**Alternatives considered**:
- *Pre-validate SVG before attempting render*: Extra I/O, no benefit over the existing pattern. Rejected.

### Decision 4: Sync result message reports icon status separately

**Choice**: Modify the sync result map to include an `iconStatus` field (e.g., `'all_ok'`, `'partial'`, `'all_failed'`) and update the user-facing message to say "Sync completed" with an optional note about icon issues, rather than "Sync completed with failures".

**Rationale**: Users should know if icons had issues, but the message shouldn't imply data loss. A green checkmark with a small info note is better than a red X.

**Alternatives considered**:
- *Silent icon failures*: Users wouldn't know icons are missing. Rejected — transparency is better.
- *Toast/notification per failed icon*: Too noisy for bulk syncs. Rejected.

## Risks / Trade-offs

- **[Risk] Users may not notice missing icons**: Since sync now shows "success" even with icon failures, users might not realize their icons are broken. → **Mitigation**: Sync result message includes "X icons could not be downloaded" when `failed > 0`.
- **[Risk] SVG parsing crash in flutter_svg**: The `flutter_svg` package has known limitations with complex SVGs. → **Mitigation**: `errorBuilder` already catches parse errors; adding try-catch around `_sanitizeSvg` provides defense-in-depth.
- **[Trade-off] No retry mechanism**: Failed icons are only retried on next manual/auto sync. → **Acceptable**: The core data (secrets) is intact; icons are cosmetic and can be fetched later.
