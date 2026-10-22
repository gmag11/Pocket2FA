import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/models/account_entry.dart';
import 'package:pocket2fa/models/group_entry.dart';
import 'package:pocket2fa/screens/advanced_form_screen.dart';

import '../helpers/pump.dart';

const _user = 'alice@example.test';
const _host = '';
const _secret = 'JBSWY3DPEHPK3PXP';

AccountEntry _existing({bool isBorrowed = false, String group = 'Work'}) =>
    AccountEntry(
      id: 7,
      service: 'GitHub',
      account: 'alice',
      seed: _secret,
      group: group,
      otpType: 'totp',
      digits: 8,
      algorithm: 'sha256',
      period: 45,
      isBorrowed: isBorrowed,
    );

Future<void> _pumpForm(
  WidgetTester tester, {
  AccountEntry? existing,
  List<GroupEntry>? groups,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await pumpApp(
    tester,
    AdvancedFormScreen(
      userEmail: _user,
      serverHost: _host,
      groups: groups,
      existingEntry: existing,
    ),
  );
  await tester.pump();
}

Future<AccountEntry?> _pumpRouteAndSubmit(
  WidgetTester tester, {
  List<GroupEntry>? groups,
  bool doubleTap = false,
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  AccountEntry? result;
  await pumpApp(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await Navigator.of(context).push<AccountEntry>(
              MaterialPageRoute(
                builder: (_) => AdvancedFormScreen(
                  userEmail: _user,
                  serverHost: _host,
                  groups: groups,
                ),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextFormField).at(0), 'GitHub');
  await tester.enterText(find.byType(TextFormField).at(1), 'alice');
  await tester.enterText(find.byType(TextFormField).at(2), _secret);

  await tester.tap(find.widgetWithText(OutlinedButton, '8'));
  await tester.pump();
  await tester.tap(find.widgetWithText(OutlinedButton, 'sha256'));
  await tester.pump();

  if (groups != null) {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work').last);
    await tester.pumpAndSettle();
  }

  await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
  if (doubleTap) {
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Create'),
      warnIfMissed: false,
    );
  }
  await tester.pumpAndSettle();

  return result;
}

void main() {
  testWidgets('renders the create form and action buttons', (tester) async {
    await _pumpForm(tester);

    expect(find.widgetWithText(ElevatedButton, 'Create'), findsOneWidget);
    expect(find.text('Service'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Group'), findsOneWidget);
    expect(find.text('Choose the type of OTP to create'), findsOneWidget);
    expect(find.text('TOTP'), findsOneWidget);
    expect(find.text('HOTP'), findsOneWidget);
    expect(find.text('STEAM'), findsOneWidget);
    expect(find.text('Secret'), findsOneWidget);
    expect(find.text('Options'), findsOneWidget);
    expect(find.text('Digits'), findsOneWidget);
    expect(find.text('Algorithm'), findsOneWidget);
    expect(find.text('Period'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('$_user - $_host'), findsOneWidget);
  });

  testWidgets('validates required fields and the Base32 secret', (
    tester,
  ) async {
    await _pumpForm(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('Service is required'), findsOneWidget);
    expect(find.text('Account is required'), findsOneWidget);
    expect(find.text('Secret is required'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'GitHub');
    await tester.enterText(find.byType(TextFormField).at(1), 'alice');
    await tester.enterText(find.byType(TextFormField).at(2), 'not base32!');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Secret must be Base32'), findsOneWidget);
  });

  testWidgets('switches OTP types and their dependent fields', (tester) async {
    await _pumpForm(tester);

    expect(find.text('Period'), findsOneWidget);

    await tester.tap(find.text('HOTP'));
    await tester.pump();
    expect(find.text('Counter'), findsOneWidget);
    expect(find.text('Period'), findsNothing);

    await tester.tap(find.text('STEAM'));
    await tester.pump();
    expect(find.text('Digits'), findsNothing);
    expect(find.text('Algorithm'), findsNothing);
    expect(find.text('Period'), findsNothing);
    expect(find.text('Counter'), findsNothing);
    expect(find.text('Secret'), findsOneWidget);

    await tester.tap(find.text('TOTP'));
    await tester.pump();
    expect(find.text('Period'), findsOneWidget);
    expect(find.text('Counter'), findsNothing);
  });

  testWidgets('prefills edit mode and keeps the secret locked', (tester) async {
    await _pumpForm(
      tester,
      existing: _existing(),
      groups: [GroupEntry(id: 4, name: 'Work', twofaccountsCount: 2)],
    );

    expect(find.widgetWithText(ElevatedButton, 'Save'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('alice'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);

    final secret = tester.widget<TextField>(find.byType(TextField).at(2));
    expect(secret.obscureText, isTrue);
    expect(find.byIcon(Icons.lock), findsOneWidget);

    final hotp = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'HOTP'),
    );
    expect(hotp.onPressed, isNull);

    await tester.tap(find.byIcon(Icons.lock));
    await tester.pump();

    final unlocked = tester.widget<TextField>(find.byType(TextField).at(2));
    expect(unlocked.obscureText, isFalse);
    expect(find.byIcon(Icons.lock_open), findsOneWidget);
  });

  testWidgets('borrowed entries pop without rendering an editable form', (
    tester,
  ) async {
    AccountEntry? result;
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await Navigator.of(context).push<AccountEntry>(
                MaterialPageRoute(
                  builder: (_) => AdvancedFormScreen(
                    userEmail: _user,
                    serverHost: _host,
                    existingEntry: _existing(isBorrowed: true),
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(AdvancedFormScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('submits a local entry with selected options', (tester) async {
    final groups = [GroupEntry(id: 4, name: 'Work', twofaccountsCount: 2)];
    final result = await _pumpRouteAndSubmit(tester, groups: groups);

    expect(result, isNotNull);
    final entry = result!;
    expect(entry.service, 'GitHub');
    expect(entry.account, 'alice');
    expect(entry.seed, _secret);
    expect(entry.group, 'Work');
    expect(entry.groupId, 4);
    expect(entry.digits, 8);
    expect(entry.algorithm, 'sha256');
    expect(entry.otpType, 'TOTP');
    expect(entry.period, 30);
  });

  testWidgets('guards against duplicate submissions', (tester) async {
    final result = await _pumpRouteAndSubmit(tester, doubleTap: true);

    expect(result, isNotNull);
    expect(result!.service, 'GitHub');
  });
}
