# Tasks

## 1. Icon cache

- [x] 1.1 Add `test/unit/services/icon_cache_service_test.dart` with a path-provider mock and pre-seeded cache files; assert the cache hit; verify with `flutter test test/unit/services/icon_cache_service_test.dart`.
- [x] 1.2 Cover sanitized paths, evict/clear and their no-op repeats; verify the file passes.

## 2. Incoming image helpers

- [x] 2.1 Add `test/unit/services/incoming_image_processor_test.dart` for descriptor parsing, rejection/failure messages and working-copy deletion; verify with `flutter test test/unit/services/incoming_image_processor_test.dart`.
- [x] 2.2 Cover the server-missing `process` branch without invoking the QR decoder; verify the file passes.

## 3. Integration and coverage

- [x] 3.1 Run `flutter test --coverage` and verify every test passes and `dart run tool/check_coverage.dart` still reports all 44 non-generated files instrumented.
- [x] 3.2 Raise `.coverage-baseline` to the measured overall value only after the full run, then rerun the gate and verify the ratchet passes at the new floor.
- [x] 3.3 Run `flutter analyze` and `dart format` on the new test files; verify no analyzer issues and no unintended changes under `lib/`.

## Workflow follow-up

- Archive the change after review.
