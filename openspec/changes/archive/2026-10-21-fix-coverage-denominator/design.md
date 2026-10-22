# Design

## Context

`flutter test --coverage` writes an lcov record only for libraries that the
compiled test kernel loads. Before this change, `check_coverage.dart` summed
those records directly, so importing fewer modules made the percentage look
better. The testing-infrastructure spec already requires the overall metric to
cover all non-generated `lib/` code; the implementation did not.

## Goals / Non-Goals

**Goals:**

- Make every non-generated `lib/` file part of the coverage denominator,
  whether or not a behavioral test executes it.
- Make a missing or uninstrumented file a hard failure with an actionable
  message.
- Keep the gate fast and dependency-free.

**Non-Goals:**

- Estimating executable lines statically for files absent from lcov.
- Changing the 70% target or counting generated `lib/l10n/` files.

## Decisions

### Import the whole tree in a dedicated test

A test that imports every library makes the Dart VM compile those libraries, so
`lcov.info` contains their executable lines with zero hits. The test only
imports `main.dart` with a prefix and references `app.main`; it never calls
application code or platform channels. An import-only test was verified to
instrument an otherwise unloaded service with 127 lines at 0%.

Alternatives considered:

- **Count source lines for absent files.** Comments, blank lines and
  declarations would inflate the denominator, and the metric would switch
  definitions the moment a file gets imported.
- **Parse Dart with the analyzer.** Accurate executable-line counting would add
  a dependency and duplicate what the VM already reports.

### Fail instead of shrinking the denominator

`check_coverage.dart` walks `lib/`, excludes `lib/l10n/`, and compares that list
with the lcov records. Missing files, or records with no executable lines, exit
with status 2 and name each file. This prevents a future test refactor from
silently dropping modules again. A full-suite run is required; a subset run is
expected to fail the gate.

### Rebase the baseline once

The old 70.0 was measured over a different denominator. Keeping it would make
the corrected metric fail forever without reflecting a regression. The baseline
is set to the measured 15.62 and the file records why the number changed. From
there, the normal ratchet rule applies again.

## Risks / Trade-offs

- **The import test must be updated when a library is added** → the gate fails
  and names the missing file, so the omission is caught in the same run.
- **Platform-specific code can change instrumented line counts** → the project
  runs the suite on Linux; a different platform may need its own baseline.
- **The corrected number is much lower (15.62%)** → this is the honest starting
  point; planning now has to cover screens, widgets and the remaining services.
