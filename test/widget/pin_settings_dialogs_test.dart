import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/screens/pin_settings_dialogs.dart';
import 'package:pocket2fa/services/settings_service.dart';

import '../helpers/fakes/fake_settings_storage.dart';
import '../helpers/pump.dart';

void main() {
  testWidgets('warning dialog returns cancel and accept results', (
    tester,
  ) async {
    bool? accepted;

    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              accepted = await showPinForgotWarningDialog(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Warning: forgotten PIN'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(accepted, isFalse);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(accepted, isTrue);
  });

  testWidgets('new PIN dialog validates length and confirmation', (
    tester,
  ) async {
    String? pin;

    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              pin = await showSetPinDialog(context, title: 'Set PIN');
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Set PIN'), findsOneWidget);
    expect(find.text('Enter your PIN'), findsOneWidget);
    expect(find.text('Confirm PIN'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '123');
    await tester.enterText(find.byType(TextField).at(1), '123');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('PIN must be 4 to 8 digits'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '1234');
    await tester.enterText(find.byType(TextField).at(1), '5678');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('PINs do not match'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), '1234');
    await tester.enterText(find.byType(TextField).at(1), '1234');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Set PIN'), findsNothing);
    expect(pin, '1234');
  });

  testWidgets('new PIN dialog can be cancelled', (tester) async {
    String? pin = 'unchanged';

    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              pin = await showSetPinDialog(context, title: 'Set PIN');
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(pin, isNull);
  });

  testWidgets('current factor rejects an empty PIN without biometrics', (
    tester,
  ) async {
    final settings = SettingsService(storage: FakeSettingsStorage());
    await settings.reloadFromStorage();
    CurrentFactorVerification? verification;

    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              verification = await showCurrentFactorDialog(
                context,
                settings: settings,
                title: 'Change PIN',
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
      settings: settings,
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Change PIN'), findsOneWidget);
    expect(find.text('Use biometrics'), findsNothing);

    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect PIN'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(verification, isNull);
  });
}
