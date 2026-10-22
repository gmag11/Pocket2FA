import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/screens/image_qr_scanner_screen.dart';

import '../helpers/pump.dart';

void main() {
  testWidgets('renders the image scanner content', (tester) async {
    await pumpApp(
      tester,
      const ImageQrScannerScreen(
        userEmail: 'alice@example.test',
        serverHost: 'example.test',
      ),
    );

    expect(find.text('Select QR Image'), findsOneWidget);
    expect(
      find.text('Select an image from gallery containing a QR code'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.image), findsOneWidget);
    expect(find.text('Select Image'), findsOneWidget);
    expect(find.byIcon(Icons.photo_library), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('pops back to the previous route', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ImageQrScannerScreen(
                  userEmail: 'alice@example.test',
                  serverHost: 'example.test',
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ImageQrScannerScreen), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.byType(ImageQrScannerScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
