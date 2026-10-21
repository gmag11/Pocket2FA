import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/screens/image_qr_scanner_screen.dart';
import 'package:pocket2fa/screens/new_code_screen.dart';

import '../helpers/pump.dart';

const _user = 'alice@example.test';
const _host = 'example.test';

Future<void> _setTallSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  testWidgets('renders the new-code actions and footer', (tester) async {
    await _setTallSurface(tester);
    await pumpApp(
      tester,
      const NewCodeScreen(userEmail: _user, serverHost: _host),
    );

    expect(find.text('Create new code'), findsOneWidget);
    expect(find.text('Choose how to create a new code:'), findsOneWidget);
    expect(find.text('Scan QR code'), findsOneWidget);
    expect(find.text('Alternate methods'), findsOneWidget);
    expect(find.text('Select Image'), findsOneWidget);
    expect(find.text('Use the advanced form'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('$_user - $_host'), findsOneWidget);
  });

  testWidgets('shows the unsupported-camera message on Linux', (tester) async {
    await _setTallSurface(tester);
    await pumpApp(
      tester,
      const NewCodeScreen(userEmail: _user, serverHost: _host),
    );

    await tester.tap(find.text('Scan QR code'));
    await tester.pump();

    expect(
      find.text(
        "Camera scanning isn't supported on this platform. Use the select image option or the advanced form.",
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('navigates to the image scanner and back through both screens', (
    tester,
  ) async {
    await _setTallSurface(tester);
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    const NewCodeScreen(userEmail: _user, serverHost: _host),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(NewCodeScreen), findsOneWidget);

    await tester.tap(find.text('Select Image'));
    await tester.pumpAndSettle();
    expect(find.byType(ImageQrScannerScreen), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(NewCodeScreen), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });
}
