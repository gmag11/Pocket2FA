import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/l10n/app_localizations.dart';

import '../helpers/pump.dart';

void main() {
  testWidgets('pumpApp provides the app localization delegates', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Text(AppLocalizations.of(context)!.appTitle),
      ),
    );

    expect(find.text('Pocket2FA'), findsOneWidget);
  });
}
