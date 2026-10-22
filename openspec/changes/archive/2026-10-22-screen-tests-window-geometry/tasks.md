# Tasks

## 1. Window geometry lifecycle

- [x] 1.1 Add `test/services/window_geometry_service_test.dart` with mocked `window_manager` methods; cover platform support, `init` and `showWindow`; verify with `flutter test test/services/window_geometry_service_test.dart`.
- [x] 1.2 Cover the debounced resize save and persisted bounds; verify the file passes.
- [x] 1.3 Cover the close handshake (`setPreventClose(false)` and `close`); verify the file passes.

## 2. Integration and coverage

- [x] 2.1 Run `flutter test --coverage` and verify every test passes and `dart run tool/check_coverage.dart` still reports all 44 non-generated files instrumented.
- [x] 2.2 Raise `.coverage-baseline` to the measured overall value only after the full run, then rerun the gate and verify the ratchet passes at the new floor.
- [x] 2.3 Run `flutter analyze` and `dart format` on the new test file; verify no analyzer issues and no unintended changes under `lib/`.

## Workflow follow-up

- Archive the change after review.
