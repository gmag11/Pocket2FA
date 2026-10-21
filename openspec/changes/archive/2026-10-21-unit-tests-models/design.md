# Design

## Context

The three models are plain Dart with no plugin or network dependency. They are
already loaded by the existing suite, so adding tests only needs
`flutter_test` and the builders defined in the test files. See `proposal.md`
for motivation.

## Goals / Non-Goals

**Goals:**

- Cover every public member of the three models, including defaulting and
  coercion paths used by legacy payloads.
- Keep each test independent and readable by overriding only the field under
  test.

**Non-Goals:**

- Fixing behavior the tests may expose; this change is characterization only.
- Testing services, widgets, Hive, or API calls.
- Reaching 70% coverage in this stage.

## Decisions

- **One test file per model**, mirroring `lib/models/`. Failure output stays
  localized and the files map directly to the code under test.
- **Local builder instead of shared fixtures.** `UserPreferences` has 33
  required fields; a `preferencesWith(...)` helper in its test file keeps
  cases short. Move it to `test/helpers/` only if a later stage reuses it.
- **Assert full round-trips with `toMap`/`fromMap`**, plus targeted assertions
  for defaults and coercion. Round-trips catch key mismatches (for example
  `revealDottedOTP` and `AutoSaveQrcodedAccount`) that field-by-field checks
  miss.
- **No production changes.** If a test reveals a real defect, record it and
  fix it in a separate change so this stage stays a pure coverage increment.
- **Raise the baseline to the measured overall value rounded down**, keeping
  the ratchet strict without pinning a number the suite cannot reproduce.

## Risks / Trade-offs

- [Characterization tests can cement a bug] → Treat surprising behavior as a
  finding to review, not as a silently accepted expectation; document it in the
  final summary.
- [Coverage target depends on all branches being reachable] → Use the measured
  value for the baseline, and keep 30.00% as the minimum acceptance target
  rather than an exact prediction.
