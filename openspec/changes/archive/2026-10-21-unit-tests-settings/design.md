# Design

## Context

`SettingsService` has two load/save paths: an injected `SettingsStorage` (Hive)
and a `SharedPreferences` fallback. The fake already answers box reads and
lock state in memory; the existing `resetSettingsService()` helper awaits the
initial load. See `proposal.md` for motivation.

## Goals / Non-Goals

**Goals:**

- Exercise both storage paths and the locked/error branch without plugins.
- Prove setters persist, notify, and respect the locked-storage guard.
- Validate the PIN helpers against a published PBKDF2 vector.

**Non-Goals:**

- Initializing Hive, secure storage, or `local_auth`.
- Testing real biometric prompts or PIN enrolment end to end.
- Covering `ApiService` or widget code.

## Decisions

- **Use the real service, not a mock.** `SettingsService` is the unit under
  test; mocking it would assert nothing. The fake boundary stays at
  `SettingsStorage` and `SharedPreferences`.
- **Await `reloadFromStorage()` after construction.** The constructor starts
  `_load()` without exposing its future; reloading makes each test
  deterministic without sleeping.
- **Add only the missing lock metadata to the fake.** An optional
  `storageError` value is enough for the error path; biometric and PIN calls
  remain out of scope.
- **Reset `LogService` around every test.** The debug-logging setter mutates
  the singleton, so tests must not depend on execution order.
- **Use a published PBKDF2-HMAC-SHA256 vector** plus a two-iteration case to
  execute the XOR loop, and a low iteration count to keep the suite fast.

## Risks / Trade-offs

- [Singleton state leaks between tests] → Call `resetLogService()` in
  `setUp`/`tearDown` and create a fresh `SettingsService` per test.
- [PBKDF2 vectors can be slow] → Use 1–2 iterations for correctness and a
  small custom case for the loop, not the 50,000 production count.
- [Locked-storage defaults could hide a regression] → Assert the explicit
  defaults and that `box` is never touched while locked.
