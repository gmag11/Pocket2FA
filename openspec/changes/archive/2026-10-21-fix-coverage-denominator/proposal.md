# Proposal

## Why

The coverage gate only counted files that appeared in `coverage/lcov.info`.
Files that no test imported were silently left out of the denominator, so the
reported "70.54% overall" was really 70.54% of 10 loaded files, while 34 of the
44 non-generated `lib/` files were not measured at all. That number could not
be compared with the 70% goal and misled planning.

## What Changes

- Add `test/coverage/import_all_test.dart`, which imports every non-generated
  library under `lib/` so the VM instruments untouched modules with 0% instead
  of omitting them.
- Make `tool/check_coverage.dart` enumerate all non-generated `lib/` sources and
  fail when a source is missing from `lcov.info` or has no executable lines.
  The report also states how many files were instrumented.
- Rebase `.coverage-baseline` from the old loaded-files metric (70.0) to the
  real all-files value (15.62). The target remains 70%.
- Keep `lib/l10n/` excluded from both the numerator and the denominator.

No application code changes and no new dependencies.

## Capabilities

### New Capabilities

None. This is test tooling; behavior does not change, so the change declares
`skip_specs: true`.

### Modified Capabilities

None.

## Impact

- New import-only test under `test/coverage/`.
- `tool/check_coverage.dart` validates the complete file set.
- `.coverage-baseline` is re-expressed in the corrected metric; the previous
  70.0 is not comparable because its denominator was different.
