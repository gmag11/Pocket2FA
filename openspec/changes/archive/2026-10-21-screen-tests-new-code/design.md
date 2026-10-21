# Design

## Context

See `proposal.md` - Why. `NewCodeScreen` is a stateless chooser with four
actions: scan QR, select an image, use the advanced form and go back. The scan
action checks the platform and shows a SnackBar on Linux/Windows/Web, where the
camera scanner is unavailable. The image action pushes `ImageQrScannerScreen`.

`ImageQrScannerScreen` is a stateful screen that shows an image icon,
instructions, a gallery button and a back button. Its gallery button calls
`ImagePicker`, which is not exercised here.

Both screens use `pumpApp` localization. A tall test surface avoids layout
overflow in the chooser.

## Goals / Non-Goals

**Goals:**

- Cover the rendered actions and footer of both screens.
- Cover the Linux camera-unsupported branch.
- Cover navigation to the image scanner and back to the previous route.
- Keep the tests free of camera, image-picker and network plugins.

**Non-Goals:**

- Scanning a real QR code or opening the camera.
- Picking an image from the gallery.
- Opening the advanced form.
- Testing the actual entry-creation/upload path.

## Decisions

### New-code render

Pump `NewCodeScreen(userEmail: 'alice@example.test', serverHost:
'example.test')` inside `pumpApp` with a tall surface. Assert the title, the
choose/alternate headings, the scan/image/advanced/back buttons and the
user-at-host footer.

### Camera unsupported

The test host is Linux, so tapping Scan QR takes the unsupported-platform branch
and shows `cameraNotSupportedMessage` without touching `flutter_zxing`. Assert
the SnackBar, then pump past its duration.

### Navigation through a route harness

For navigation and back tests, pump a `Scaffold` with a button that pushes
`NewCodeScreen` via `Navigator.push`. Tapping Select Image pushes
`ImageQrScannerScreen`; assert it appears, tap its Back button, assert the
chooser returns, then tap the chooser's Back button and assert the initial
button is visible again. This exercises both `Navigator.pop` calls without
rebuilding the screens as roots.

### Image scanner render

Pump `ImageQrScannerScreen` directly and assert its title, instruction, gallery
button and back button. Do not tap the gallery button; that would call the
`image_picker` plugin.

### Avoid the advanced form

The advanced form is a large stateful form with its own dependencies; this stage
only asserts that its button is present. Covering it belongs to a dedicated
stage.

## Risks / Trade-offs

- **Chooser layout** → use a tall surface (`800x1000`) and reset it in
  `addTearDown`.
- **Platform branch** → the test host is Linux; do not assume Android camera
  support.
- **SnackBar timer** → pump two seconds after the camera message.
- **Image picker** → never tap the gallery button.
- **Route stack** → push from a real button so `Navigator.pop` has a route to
  return to.
- **Advanced form** → render the button only; do not push it.

## Migration Plan

Not applicable: test-only change. Rollback is deleting the new tests and
restoring the previous baseline.

## Open Questions

None that affect scope. Exact coverage will be measured after the tests run.
