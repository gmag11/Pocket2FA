# Design

## Context

See `proposal.md` - Why. `SettingsStorage` opens an encrypted Hive box with a
key kept in `FlutterSecureStorage`, optionally gates key release behind
biometrics, and stores PIN material in secure storage. `init` resolves a
platform directory; on desktop it uses `getApplicationSupportDirectory`.

## Goals / Non-Goals

**Goals:**

- Open and use the encrypted box with fake platform storage.
- Cover PIN metadata/hash/salt/lockout and biometric flag branches.
- Cover secure-storage failure and locked-state behavior.
- Keep the tests deterministic and leave no Hive files behind.

**Non-Goals:**

- Real keystore/keychain or local-auth prompts.
- Platform-specific encryption internals.
- UI lock screen rendering (already covered separately).

## Decisions

### Test-only platform doubles

Set `FlutterSecureStoragePlatform.instance` to an in-memory fake and
`LocalAuthPlatform.instance` to a fake whose support/authenticate results are
controllable. This avoids method-channel/Federated plugin differences. If a
direct import is needed, add the already-transitive platform-interface packages
as dev dependencies.

### Temporary Hive directory

Mock `getApplicationSupportDirectory` through the path-provider channel to a
unique temp directory, call `SettingsStorage.init()`, then close Hive and delete
the directory in teardown. Each test creates a fresh storage instance and a
fresh directory so encrypted-box state cannot leak.

### Lifecycle coverage

Cover:

- empty secure storage -> generated key, encrypted box, unlocked;
- key present -> reuse and open;
- secure read failure -> locked with `storageError`;
- biometric flag + unsupported/supported/cancelled prompt;
- PIN set/verify/change/clear, wrong PIN, lockout duration and reset;
- biometric enable/disable flag persistence;
- `readKey` with and without auth requirements.

### Time and hashing

Use the existing `withFixedTime` helper where lockout timing matters. PIN hashes
use the real PBKDF2 helper but small iteration counts are not configurable; use
the production default and assert behavior, not speed.

### Baseline pin

If overall coverage reaches 70.0, set the baseline to 70.0 and leave it pinned.

## Risks / Trade-offs

- **Hive encryption key format** → use the same encoded key path the production
  code expects; assert round-trip rather than key bytes.
- **Federated plugins** → platform-instance fakes instead of channel names.
- **Global Hive** → close boxes and delete temp dirs in teardown.
- **Biometric callbacks** → controlled fake results; no real prompt.
- **PIN hashing cost** → a few tests only; default iterations stay realistic.
- **Platform detection** → tests run on Linux; keep the desktop directory path.
- **Singleton state** → instantiate a fresh `SettingsStorage` per test.

## Migration Plan

Not applicable: test-only change. Rollback is deleting the new tests and
restoring the previous baseline.

## Open Questions

None that affect scope. Exact coverage will be measured after the tests run.
