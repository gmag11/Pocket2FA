# Design

## Context

See `proposal.md` - Why. The relevant current state:

- `SettingsStorage.init()` (`lib/services/settings_storage.dart:42`) reads the biometric flag
  and the Hive key in a single `_secure.readAll()`. Any exception is swallowed by a broad
  `catch` (`:122`) that leaves `_unlocked = false` and prints to `debugPrint` only — it never
  records *why* the store is locked, and never reaches `LogService`.
- `SettingsStorage.attemptUnlock()` (`:156`) returns `true` early when biometric protection is
  off (`biometricFlag != '1'`) **without opening the box**, and returns `false` when
  `local_auth` is unavailable. On Linux `canCheckBiometrics`/`isDeviceSupported()` throw
  `MissingPluginException`, so the call always fails.
- `SettingsService._load()` (`lib/services/settings_service.dart:46`) caches
  `biometricsSupported` from `supportsBiometrics()`; on Linux this is always `false`.
- `HomePage.build()` (`lib/screens/home_screen.dart:413`) renders a single hard-coded
  `l10n.biometricAuthFailed` message and a Retry button whenever `!storage.isUnlocked`,
  regardless of the real cause.
- `pubspec.lock` currently pins `flutter_secure_storage_linux` 3.0.1, whose `warmupKeyring()`
  enumerates all collections and fails on any unrelated broken item.

Constraints: the app cannot make `libsecret` enumerate collections more tolerantly from Dart,
and the plugin's internal `LOAD_COLLECTIONS` call is not configurable. What the app *can* do is
(a) pick a plugin version that drops `LOAD_COLLECTIONS`, (b) not collapse distinct failures into
one misleading state, and (c) actually retry the storage path on demand.

## Goals / Non-Goals

**Goals**

- A secure-storage failure is recoverable: Retry re-runs the read/open path and can succeed.
- The locked screen tells the truth: a keyring/storage failure is not reported as a biometric
  failure, and no biometric Retry is offered where biometrics cannot work.
- The failure cause is recorded in the debug log.
- Remove the upstream `LOAD_COLLECTIONS` trigger by using the stable plugin fix.

**Non-Goals**

- Implementing biometric authentication on Linux (there is no plugin support).
- Changing the biometric-protection opt-in flow, storage format, or encrypted data.
- Adopting `flutter_secure_storage` 4.0.0 (prerelease; migrates legacy `xdg:schema` items and
  writes to the keyring — to be evaluated on a branch, see #1181).
- Automatically repairing or deleting third-party items in the user's OS keyring.

## Decisions

### Decision 1: Bump the transitive `flutter_secure_storage_linux` to 3.0.3

The root trigger is the plugin's `LOAD_COLLECTIONS` enumeration of the whole keyring. 3.0.3
removes it ("Do not load all collections here: some Secret Service backends fail when an
unrelated stale item exists in another collection"). The existing constraint already permits
3.0.3, so this is a lockfile-only change — no `pubspec.yaml` edit, no `dependency_overrides`.

**Alternative considered:** add `flutter_secure_storage_linux` as a direct dependency to force a
minimum. Rejected: it promotes a platform implementation to a direct dependency for no benefit;
`flutter pub upgrade`/the committed lock is enough and matches the issue's guidance.

### Decision 2: Model the locked state explicitly instead of one boolean

`SettingsStorage` keeps `isUnlocked` and gains `isBiometricLocked` (a prompt is pending) and
`storageError`/`hasStorageError` (the secure-storage read failed). `init()` sets exactly one of
the two when it cannot unlock, and the UI maps state → message. This is what removes the
misleading message: the screen no longer assumes every lock is biometric.

**Alternative considered:** inspect exception types in the UI. Rejected: the UI should not parse
`PlatformException`s; the storage layer already knows whether the failure was a prompt or a read.

### Decision 3: `attemptUnlock()` retries the whole storage path

`init()` and `attemptUnlock()` share a private helper that (re)reads the secure values, prompts
biometrics only when protection is enabled and supported, and opens the box. `attemptUnlock()`
no longer returns `true` without opening the box when protection is off, and no longer treats a
missing `local_auth` plugin as a hard failure. A failure that occurred during a slow/broken
startup can therefore recover on Retry — as long as the underlying keyring read succeeds (which
3.0.3 makes likely).

**Alternative considered:** only re-run `init()` from the UI. Rejected: `init()` also re-runs
Hive path migration and is meant for startup; the unlock helper is the right seam.

### Decision 4: Honest, localized messaging and logging

The locked screen selects its message from `SettingsStorage` state:

1. `hasStorageError` → a storage/keyring-specific message plus the raw error detail.
2. `isBiometricLocked && !biometricsSupported` → `biometricsNotAvailable`.
3. otherwise → the existing `biometricAuthFailed`.

Failures are emitted through `LogService.instance.error(...)` so the in-app debug log (and its
export) shows the real cause, complementing the visible message.

## Risks / Trade-offs

- **Bumping the plugin ships native code** → mitigate by choosing the patch release that targets
  exactly this bug and by keeping the bump isolated in `pubspec.lock`; the constraint already
  allowed it.
- **The user's keyring may stay broken** (the offending item can belong to another app) → the app
  cannot repair it, but it now reports the real error and the documented `LD_PRELOAD` workaround
  still applies; with ≥ 3.0.3 it is usually unnecessary.
- **Bogus `xdg:schema` storage remains** until 4.0.0 → out of scope; existing items are still
  read by 3.0.x, so no data is lost by staying on the 3.x line.
- **Behavior change on Android/Windows** → the unlock helper keeps the same biometric prompt; the
  happy path (protection off) simply also opens the box, which it should have always done.

## Migration Plan

1. Lock `flutter_secure_storage_linux` 3.0.3.
2. Add the lock-state fields and the shared read/open helper in `SettingsStorage`.
3. Make `attemptUnlock()` go through that helper.
4. Update the locked screen to select the message/action from state and log failures.
5. Add the l10n strings and regenerate localizations.
6. Verify on Linux (healthy and broken keyring) and re-check Android/Windows biometric flows.

Rollback: revert the changed files and restore the previous `pubspec.lock` entry; no stored data
or format is changed, so downgrading the plugin is safe.

## Open Questions

None.
