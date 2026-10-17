# Tasks

## 0. Evidence and scope decisions

- [ ] 0.1 On issue #12, ask again for the account's icon details (filename, byte size, pixel dimensions) and the logcat captured while the app closes, and record the answer in `design.md` Open Questions
- [ ] 0.2 Confirm the size cap for icons (256 KB proposed) against the largest legitimate icon on a real 2FAuth server, and write the chosen constant into the spec/design
- [ ] 0.3 Decide whether to keep `otp-parameter-guards` in this change or split it into its own change before implementation starts
- [ ] 0.4 Confirm the crash reproduces at all on the current `dev` build with a hostile icon in the cache (see 5.1) before and after the changes

## 1. Icon cache integrity (`lib/services/icon_cache_service.dart`)

- [ ] 1.1 Replace the fixed temp path (`:53`, `'${file.path}.tmp'`) with a unique temp name per download (random suffix) so two concurrent writers can never share it
- [ ] 1.2 Add an in-flight map (`Map<String, Future<Uint8List>>` keyed by destination path) so concurrent callers for the same (server, icon) await one download instead of racing and re-downloading
- [ ] 1.3 Delete the temp file when the rename or the write fails, and log the failure (`:54` currently logs without cleanup on the rename path)
- [ ] 1.4 Add a maximum accepted icon length and enforce it in `_downloadIcon` (`:87-123`), refusing anything larger as an icon failure
- [ ] 1.5 Add signature sniffing (PNG/JPEG/GIF/WEBP/BMP/SVG) and refuse payloads that are not images, so an HTML/JSON error page is never cached
- [ ] 1.6 Validate the cache on read (`:36-42`: existence, non-zero length, size limit, signature); on failure delete the file and download instead of returning bad bytes
- [ ] 1.7 Keep `getIconFile()` behaviour unchanged (it is only a path helper) and make sure it cannot throw on odd filenames
- [ ] 1.8 Make sure a rejected icon is counted as a non-fatal icon failure so `SyncService` still reports success (see the archived `graceful-svg-icon-fallback` behaviour)

## 2. Render path (`lib/widgets/account_tile_ui.dart`)

- [ ] 2.1 Decode rasters downscaled: `ResizeImage(FileImage(file), width: 96, height: 96)` instead of the bare `FileImage` at `:76`, so decode memory is bounded by display size
- [ ] 2.2 Read the icon once per tile, keyed by path, instead of creating a new `file.readAsString()` future inside `build` (`:55`)
- [ ] 2.3 On any render failure (read, decode, SVG compile), evict the cached file once per tile instance and fall back to `fallbackAvatar()` (`:24-45`) — never retry in a loop
- [ ] 2.4 Guarantee the icon widget cannot affect the rest of the tile: verify service/account/code/next-code/countdown are built independently of the avatar's outcome
- [ ] 2.5 Review `_sanitizeSvg` (`:277-286`) in light of the size cap; keep it only if it is still needed for real icons and document why
- [ ] 2.6 Log icon render failures with the icon filename and the reason, so a report like issue #12 can be diagnosed from logcat

## 3. User-accessible cache clearing

- [ ] 3.1 Add a "clear icon cache" action to `lib/screens/settings_screen.dart` using `_buildSettingTile(...)` (`:257`), visible only where icons are used (Android/desktop)
- [ ] 3.2 Wire it to `IconCacheService.clearAll()` (`:79`) inside try/catch, reporting success or failure to the user and refreshing the list afterwards
- [ ] 3.3 Add the action's strings to `lib/l10n/app_en.arb`, `app_es.arb` and `app_fr.arb` and regenerate the localizations

## 4. OTP parameter guards (`lib/services/otp_service.dart`, `lib/widgets/account_tile_otp_service.dart`)

- [ ] 4.1 In `_totp` (`:65-107`), resolve an effective period that is never <= 0 (`period == null || period <= 0` → 30) and use it for both the time step and any caller-facing value
- [ ] 4.2 Bound `digits` to the supported range with a documented default, so `pow10(digits)` (`:168`) can never loop or grow without limit
- [ ] 4.3 Make dynamic truncation respect the real digest length (`:99-103`) so a short digest (md5, 16 bytes) cannot be indexed out of range
- [ ] 4.4 Fall back to sha1 for an unrecognised `algorithm` and log the substitution once per account
- [ ] 4.5 Wrap generation in `refreshCodes()` with error handling, set an unavailable indication on failure, and always schedule the next refresh (never leave the tile timer-less)
- [ ] 4.6 Validate the period/counter inputs in `lib/screens/advanced_form_screen.dart:530-539` so a locally created entry cannot store a non-positive period
- [ ] 4.7 Confirm the shared-account server path (`_refreshFromServer`) is unaffected by these guards and keeps the `offline` sentinel behaviour

## 5. Tests with synthetic fixtures

- [ ] 5.1 Add fixtures and tests for the cache/render path: 0-byte file, truncated PNG, oversized PNG (e.g. 4096x4096), non-image bytes (HTML), SVG with tens of thousands of paths
- [ ] 5.2 Assert that with each fixture the tile still renders the account's current and next codes and shows the placeholder avatar
- [ ] 5.3 Assert the download path rejects oversized and non-image payloads and writes nothing to the cache
- [ ] 5.4 Assert two accounts sharing an icon cause exactly one download and leave a complete file (concurrency test around the in-flight map)
- [ ] 5.5 Add unit tests for the OTP guards: period 0/negative/null, digits 0/huge/within range, unknown algorithm, short digest, and that a failing generation still schedules a refresh
- [ ] 5.6 Wire `flutter_test` into `dev_dependencies` if it is still undeclared, so these tests can actually run (currently deferred, see `fix-shared-account-otp` task 5.1)

## 6. Verification on device

- [ ] 6.1 `flutter analyze` passes with no new issues for the modified files
- [ ] 6.2 Place a hostile icon in the device cache (`adb` or a test build), scroll the account into view and confirm the app stays alive
- [ ] 6.3 `adb logcat` during 6.2 shows no `Out of memory`, no `lowmemorykiller` kill, no `F/libc`/`SIGSEGV` and no `ANR in net.gmartin.pocket2fa`
- [ ] 6.4 Confirm normal accounts still show their real icons after the size/format validation, and that a freshly installed app downloads each shared icon only once
- [ ] 6.5 Confirm the "clear icon cache" action empties the cache, shows placeholders and that the next sync restores the icons
- [ ] 6.6 Confirm Linux and Windows builds are unaffected

## 7. Housekeeping

- [ ] 7.1 Fold the still-valid parts of `fix/issue-12-concurrent-icon-io` (`381923a3`) into this change, then delete the local and remote branch (it was never merged into `dev`/`main`, has no PR and no tag)
- [ ] 7.2 When archiving this change, make sure the resulting spec actually lands in `openspec/specs/`: the archive of `2026-07-01-graceful-svg-icon-fallback` left its delta only under `openspec/changes/archive/`, and `openspec list --specs` reports 0 requirements for every spec in the repo
