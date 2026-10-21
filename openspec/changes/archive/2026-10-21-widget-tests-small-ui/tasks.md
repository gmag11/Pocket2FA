# Tasks

## 1. About dialog

- [x] 1.1 Add `test/widget/about_dialog_test.dart` that opens `AboutDialogContent` through `showDialog`, asserts the title/version/links/2FAuth note and taps Close to pop it; verify with `flutter test test/widget/about_dialog_test.dart`.

## 2. Search bar

- [x] 2.1 Add `test/widget/search_bar_test.dart` with a controller, focus node and change callback; assert the hint, typed text/callback, clear-button visibility and clearing behavior; verify with `flutter test test/widget/search_bar_test.dart`.
- [x] 2.2 Add a dark-theme render case and assert the focus is restored after clearing; verify the file passes.

## 3. Bottom bar

- [x] 3.1 Add `test/widget/bottom_bar_test.dart` covering an empty server list, a selected server summary, the first-server fallback, online/offline indicators and the selector callback; verify with `flutter test test/widget/bottom_bar_test.dart`.
- [x] 3.2 Add manage-mode cases for Delete disabled/enabled, Done and Delete callbacks; verify the file passes.

## 4. Header animation

- [x] 4.1 Add `test/widget/home_header_animation_test.dart` covering initialization, getters and the scroll-driven hide/show with a short viewport; verify with `flutter test test/widget/home_header_animation_test.dart`.
- [x] 4.2 Add a tall-viewport case that keeps the header visible and a disposal case; verify the file passes.

## 5. Server detail

- [x] 5.1 Add `test/widget/server_detail_screen_test.dart` with a server containing two accounts; assert the app bar title and both rows; verify with `flutter test test/widget/server_detail_screen_test.dart`.

## 6. Integration and coverage

- [x] 6.1 Run `flutter test --coverage` and verify every test passes and `dart run tool/check_coverage.dart` still reports all 44 non-generated files instrumented.
- [x] 6.2 Raise `.coverage-baseline` to the measured overall value only after the full run, then rerun the gate and verify the ratchet passes at the new floor.
- [x] 6.3 Run `flutter analyze` and `dart format` on the new test files; verify no analyzer issues and no unintended changes under `lib/`.

## Workflow follow-up

- Archive the change after review.
