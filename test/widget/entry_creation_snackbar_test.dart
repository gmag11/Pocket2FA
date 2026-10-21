import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/services/entry_creation_service.dart';

import '../helpers/pump.dart';
import '../helpers/reset.dart';

void main() {
  setUp(resetLogService);
  tearDown(resetLogService);

  testWidgets('invalid QR shows a localized error SnackBar', (tester) async {
    late BuildContext context;

    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (ctx) {
            context = ctx;
            return const SizedBox();
          },
        ),
      ),
    );

    final result = await EntryCreationService.parseOtpAuthUrl(
      'https://example.test/?secret=JBSWY3DPEHPK3PXP',
      context,
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(result, isNull);
    expect(find.textContaining('Error parsing QR'), findsOneWidget);
  });

  testWidgets('falls back to a plain message without localization delegates', (
    tester,
  ) async {
    late BuildContext context;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    final result = await EntryCreationService.parseOtpAuthUrl(
      'https://example.test/?secret=JBSWY3DPEHPK3PXP',
      context,
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(result, isNull);
    expect(find.textContaining('Error parsing QR:'), findsOneWidget);
  });
}
