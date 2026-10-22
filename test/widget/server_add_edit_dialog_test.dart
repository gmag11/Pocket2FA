import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/models/server_connection.dart';
import 'package:pocket2fa/screens/server_add_edit_dialog.dart';

import '../helpers/fixtures/server_connection_fixture.dart';
import '../helpers/pump.dart';

Future<void> _openDialog(
  WidgetTester tester, {
  ServerConnection? initial,
  String title = 'Add server',
  void Function(ServerConnection?)? onResult,
}) async {
  await pumpApp(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            final result = await showServerAddEditDialog(
              context: context,
              title: title,
              initial: initial,
            );
            onResult?.call(result);
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the add form and cancels with no result', (
    tester,
  ) async {
    ServerConnection? result;
    var completed = false;

    await _openDialog(
      tester,
      onResult: (value) {
        result = value;
        completed = true;
      },
    );

    expect(find.text('Add server'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('URL'), findsOneWidget);
    expect(find.text('API key'), findsOneWidget);
    expect(find.text('Accept self-signed certificates'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(3));

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Add server'), findsNothing);
    expect(completed, isTrue);
    expect(result, isNull);
  });

  testWidgets('requires a URL before attempting validation', (tester) async {
    await _openDialog(tester);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('URL required'), findsOneWidget);
    expect(find.text('Add server'), findsOneWidget);
  });

  testWidgets('prefills edit values and reveals the API key on tap', (
    tester,
  ) async {
    final server = serverConnectionFixture(
      name: 'Work',
      url: 'https://work.example.test',
      apiKey: 'secret-key',
      allowSelfSigned: true,
    );

    await _openDialog(tester, initial: server, title: 'Edit server');

    expect(find.text('Edit server'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('https://work.example.test'), findsOneWidget);

    final fields = tester
        .widgetList<TextField>(find.byType(TextField))
        .toList();
    expect(fields[2].obscureText, isTrue);

    await tester.tap(find.byType(TextField).at(2));
    await tester.pumpAndSettle();

    final cleared = tester.widget<TextField>(find.byType(TextField).at(2));
    expect(cleared.controller?.text, isEmpty);
    expect(find.byIcon(Icons.visibility_off), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pumpAndSettle();

    final revealed = tester.widget<TextField>(find.byType(TextField).at(2));
    expect(revealed.obscureText, isFalse);

    final selfSigned = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(selfSigned.value, isTrue);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
  });
}
