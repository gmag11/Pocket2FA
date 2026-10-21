import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/widgets/about_dialog.dart';

import '../helpers/pump.dart';

void main() {
  testWidgets('renders the app information and closes the dialog', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const AboutDialogContent(appVersion: '1.2.3'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Pocket2FA'), findsOneWidget);
    expect(find.text('Version: 1.2.3'), findsOneWidget);
    expect(find.text('github.com/gmag11/Pocket2FA'), findsOneWidget);
    expect(find.text('github.com/Bubka/2FAuth'), findsOneWidget);
    expect(find.textContaining('Pocket2FA requires access'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.byType(AboutDialogContent), findsNothing);
  });
}
