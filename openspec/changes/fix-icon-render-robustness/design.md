# Design

## Context

See `proposal.md` - Why. The relevant current state:

- `IconCacheService.getIconBytes()` (`lib/services/icon_cache_service.dart:28-58`) reads the cached file if it exists and returns it unvalidated; otherwise it downloads `{server}/storage/icons/{icon}` (`_downloadIcon`, `:87-123`) with no size limit, writes it to `'${file.path}.tmp'` and renames.
- `_downloadIcon` accepts any 200 response body, whatever its type or length; there is no `Content-Length` check, no `maxRedirects` reasoning and no format sniffing.
- `AccountTileUi.buildServiceAvatar()` (`lib/widgets/account_tile_ui.dart:12-86`) chooses SVG vs raster by **file extension** (line 49), reads the file to a String inside a `FutureBuilder` created during `build` (line 55), and otherwise uses `CircleAvatar(backgroundImage: FileImage(file))` (line 76) with no decode sizing.
- `IconCacheService.evict()` (`:69`) and `clearAll()` (`:79`) exist but are referenced by nothing in the app — there is no user-facing way to clear the icon cache.
- `SyncService` downloads icons in batches of `concurrency = 4` (`lib/services/sync_service.dart:30`, `:219-259`), and 2FAuth reuses icon filenames across accounts (see the duplicated `icon` values in `2FAuth-API/2fauth-api-latest.yaml`), so two tasks in the same batch can target the same destination path.
- `OtpService._totp()` (`lib/services/otp_service.dart:65-107`) divides by `acct.period` before any guard (`:76`) and indexes `digest[offset + 3]` for every algorithm (`:100-103`), which overruns a 16-byte md5 digest; `pow10()` (`:168`) loops `digits` times; and `AccountTileOtpService.refreshCodes()` is called unawaited with no error handling (`lib/widgets/account_tile_totp.dart:61`).
- The app sets `PlatformDispatcher.instance.onError` and returns `false` (`lib/main.dart:44-47`), so uncaught asynchronous Dart errors only reach logcat. This is why a Dart-level failure can never look like "the app disappears", and why the crash must be attacked at the memory/native boundary.

Constraints: the reporter's server is not reproducible here, the crash is only observable on device, and an OOM/native abort cannot be caught in Dart — so the design must make the dangerous inputs impossible rather than merely handle their errors.

## Goals / Non-Goals

**Goals**

- No icon payload can make the app exceed a bounded amount of memory or reach a decoder in a shape it cannot survive.
- The icon cache is always internally consistent, always re-validated, and repairable by the user without reinstalling.
- The tile always renders its code, whatever happens to its icon.
- An unusual account (odd period, digits or algorithm) can never throw out of the OTP path or leave a tile without a scheduled refresh.
- Make the crash reproducible in a test environment, so the fix does not depend on the reporter's data.

**Non-Goals**

- Finding out exactly which byte sequence killed the reporter's phone before the guards are in place (the guards are the fix; the evidence is for closing the issue).
- Server-side icon transcoding, or asking 2FAuth to render icons differently.
- Reworking the icon cache layout (paths stay `<server>__<icon>`), adding a database migration, or changing `AccountEntry` unless a persisted invalidation marker proves necessary.
- Retry scheduling for failed icon downloads (icons stay cosmetic and retry on the next sync).
- Any UI redesign beyond one Settings action.

## Decisions

### Decision 1: Make the temp file unique and coalesce concurrent downloads

`getIconBytes()` writes to `'${file.path}.<random>.tmp'` and keeps a `Map<String, Future<Uint8List>>` of in-flight downloads keyed by the destination path, so a second caller for the same icon awaits the first result instead of downloading and writing again.

**Why:** the fixed `.tmp` name defeats the atomic rename entirely when two accounts share an icon (2FAuth reuses files, and the batch size is 4). A unique name makes the rename genuinely atomic, and the in-flight map removes the redundant work and the window in which two writers can interleave. This is the piece the previous attempt (`381923a3`) was missing, and it is also what makes a reinstall scenario stop re-poisoning the cache.

**Alternatives considered:** (a) serialize icon downloads (`concurrency = 1`) — removes the race but makes sync slower on large accounts; rejected. (b) lock files with `flock` — no Dart API, and the in-flight map is sufficient because all writers live in one isolate.

### Decision 2: Bound icon size at download time and reject what is not an image

`_downloadIcon()` applies a maximum accepted length (256 KB proposed) using the response length/streamed bytes, and the accepted payload must match a small allowlist of signatures (PNG, JPEG, GIF, WEBP, BMP, or text-based SVG starting with `<?xml`/`<svg`). Anything else is refused as a download failure, which the sync already treats as non-fatal.

**Why:** a 3000x3000 PNG looks perfectly valid and is trivially uploaded as an icon, yet it decodes to tens of megabytes; and a misconfigured server can answer a missing icon with an HTML page and a 200. Rejecting on shape and size means the two pathological inputs never reach a decoder. Failing the download (rather than storing garbage) is what makes the existing "icon unavailable" path kick in, and it is honest: the app cannot render that icon.

**Alternative considered:** keep accepting anything and only guard at render time. Rejected — the download is the last point where the bytes can be rejected cheaply, and storing a known-bad file only to detect it later wastes the cache.

**Trade-off:** the limit is a heuristic; an account whose icon exceeds it shows a letter placeholder until the user shrinks the icon on the server. Documented, and tunable in one constant.

### Decision 3: Validate on read, and self-heal instead of trusting the cache

`getIconBytes()` re-validates what it finds on disk (existence, non-zero length, size cap, signature) and, when validation fails, deletes the file and downloads again. At render time, a failure to read/decode evicts the cached copy and shows the placeholder for this frame, with a per-tile guard so the eviction happens at most once per tile instance.

**Why:** today the cache is write-once and never checked, so a file poisoned by any past version stays poisoned forever — which is precisely why installing a newer APK could not fix the reporter's problem. Re-validation turns "poisoned forever" into "recovered on the next sync", and the once-per-tile guard prevents an evict/refetch loop if the server keeps serving the same bad bytes.

### Decision 4: Decode raster icons downscaled, and read the file once per tile

The raster branch becomes `ResizeImage(FileImage(file), width: 96, height: 96)` (2x the 18 px avatar radius, enough for any density) and the SVG branch reads the file once, in `didChangeDependencies`/`initState`-style state, keyed by the file path, instead of creating a new future inside `build`.

**Why:** decode size is the single lever that makes an oversized-but-accepted raster survive; capping the decode means even a mistakenly accepted large image costs kilobytes of memory instead of tens of megabytes. Reading once stops repeated I/O and repeated SVG compilation for a widget that rebuilds on every code refresh.

**Alternative considered:** reject any raster above a pixel threshold by parsing the header. More code, and `ResizeImage` already makes the decoded footprint safe.

### Decision 5: Icons are best-effort; the code is not

The tile's icon widget is wrapped so that any failure inside it (including the SVG compile path) resolves to `fallbackAvatar()` and the rest of the tile — service, account, code, next code, countdown — is built independently of it.

**Why:** the icon is cosmetic and the tile's reason to exist is the code. The architecture should express that: the code path must not be able to fail because of the icon path. This also gives the regression test a clean assertion: with a hostile icon in the cache, the code is still displayed.

### Decision 6: Expose the existing cache-clear and harden the OTP parameters

A "clear icon cache" entry is added to Settings (Android/desktop, wrapped in try/catch), calling the existing `IconCacheService.clearAll()`; and `OtpService._totp()` gains guards: non-positive/missing `period` → 30, `digits` clamped to a supported range with a documented default, unknown `algorithm` → sha1, and dynamic truncation that respects the actual digest length (so md5 can no longer overrun). `AccountTileOtpService.refreshCodes()` wraps generation in try/catch and always ends by scheduling the next refresh.

**Why:** `clearAll()` already exists and is dead code — the cheapest possible fix for "a user's cache is bad and they cannot clear it". The OTP guards are the same failure class as the crash: a single unusual account turning into a user-visible break. `refreshCodes()` currently has no error handling at all, so one thrown `UnsupportedError` (period 0 from a locally created entry, which the advanced form allows because it uses `int.tryParse` without range validation, `lib/screens/advanced_form_screen.dart:530-535`) leaves the tile stuck at `------` with no timer scheduled.

**Alternative considered:** validate in the advanced form only. Rejected — server-provided values never pass through that form, so the guard has to live in the generator.

## Risks / Trade-offs

- **Size limit hides legitimate icons** → 256 KB is generous for an icon; the trade-off (placeholder instead of a memory-exhausting decode) is deliberate and the constant is easy to raise. Logged so it can be diagnosed.
- **Clearing the cache on render failure delays the icon** → the placeholder is already the fallback for a missing icon; the eviction only removes a copy that could not be displayed anyway.
- **Downscaled decode changes appearance slightly** → 96 px for an 18 px radius avatar is above the pixel density of any real device; visually identical.
- **The OTP guards change behavior for out-of-range values** (period 0 now yields 30-second codes instead of a broken tile) → this is the intent; documented in the spec so it is not mistaken for a regression.
- **The root cause of issue #12 is still unproven** → the guards are justified on their own merits (bounded memory, consistent cache, no icon-driven failure), but closing the issue should wait for the reporter's icon/logcat to confirm which trigger it was.
- **Two capabilities in one change** → `otp-parameter-guards` is independent of the icon work and can be split into its own change if review prefers it.

## Migration Plan

1. Add the in-flight map, unique temp name, size/signature validation and read-time re-validation to `IconCacheService`.
2. Rework the avatar render path (downscaled decode, single read, evict-on-failure, placeholder guarantee).
3. Add the OTP parameter guards and the always-reschedule behavior.
4. Add the Settings "clear icon cache" action and its strings.
5. Add the synthetic-fixture tests (truncated, 0 bytes, oversized PNG, path-heavy SVG) and assert the tile still renders its code.
6. Manual pass on a device with logcat: no `Out of memory`, no `F/libc`/`SIGSEGV`, no `ANR`; icons still appear for normal accounts.
7. Fold in and delete `fix/issue-12-concurrent-icon-io`.

Rollback: revert the touched files; the cache format is unchanged, so older builds keep working with whatever the new build wrote (they simply lose the new validation).

## Open Questions

1. **Size cap value** — 256 KB proposed for downloads and cache acceptance. Confirm against the largest legitimate icon the maintainer's servers have.
2. **Should oversized icons fail the download or be stored and ignored?** Failing is proposed (keeps the cache clean and honest); storing would allow a manual inspection later.
3. **Evidence for issue #12** — the account's icon (name, size, pixel dimensions) and logcat from the reporting user. Nice to have before declaring the issue fixed, not a blocker for this change.
