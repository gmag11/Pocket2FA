import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/screens/accounts_screen.dart';
import 'package:pocket2fa/screens/server_detail_screen.dart';
import 'package:pocket2fa/services/settings_service.dart';

import '../helpers/fakes/fake_settings_storage.dart';
import '../helpers/fixtures/server_connection_fixture.dart';
import '../helpers/pump.dart';

Future<SettingsService> _settings(FakeSettingsStorage storage) async {
  final service = SettingsService(storage: storage);
  await service.reloadFromStorage();
  return service;
}

Future<void> _pumpAccounts(
  WidgetTester tester,
  FakeSettingsStorage storage,
) async {
  final settings = await _settings(storage);
  await pumpApp(
    tester,
    AccountsScreen(storage: storage, settings: settings),
    settings: settings,
  );
  await tester.pump();
}

void main() {
  testWidgets('renders the servers loaded from storage', (tester) async {
    final server = serverConnectionFixture(name: 'Work');
    final storage = FakeSettingsStorage(
      initialValues: {
        'servers': [server.toMap()],
      },
    );

    await _pumpAccounts(tester, storage);

    expect(find.text('Accounts / Servers'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('http://example.test'), findsOneWidget);
  });

  testWidgets('opens and cancels the add dialog', (tester) async {
    final server = serverConnectionFixture(name: 'Work');
    final storage = FakeSettingsStorage(
      initialValues: {
        'servers': [server.toMap()],
      },
    );
    await _pumpAccounts(tester, storage);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Add server'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Add server'), findsNothing);
    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('opens and cancels the edit dialog', (tester) async {
    final server = serverConnectionFixture(name: 'Work');
    final storage = FakeSettingsStorage(
      initialValues: {
        'servers': [server.toMap()],
      },
    );
    await _pumpAccounts(tester, storage);

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    expect(find.text('Edit server'), findsOneWidget);
    expect(find.text('Work'), findsWidgets);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Edit server'), findsNothing);
  });

  testWidgets('cancels and confirms deleting a server', (tester) async {
    final server = serverConnectionFixture(name: 'Work');
    final storage = FakeSettingsStorage(
      initialValues: {
        'servers': [server.toMap()],
      },
    );
    await _pumpAccounts(tester, storage);

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
    expect(find.text('Delete server'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Work'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Work'), findsNothing);
  });

  testWidgets('opens the server detail route', (tester) async {
    final server = serverConnectionFixture(name: 'Work');
    final storage = FakeSettingsStorage(
      initialValues: {
        'servers': [server.toMap()],
      },
    );
    await _pumpAccounts(tester, storage);

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();

    expect(find.byType(ServerDetailScreen), findsOneWidget);
    expect(find.text('Server: Work'), findsOneWidget);
  });

  testWidgets('shows the locked-storage error surface', (tester) async {
    final storage = FakeSettingsStorage(
      unlocked: false,
      storageError: 'keyring unavailable',
    );

    await _pumpAccounts(tester, storage);

    expect(find.text('Local data is protected'), findsOneWidget);
    expect(
      find.textContaining('Could not read the secure storage'),
      findsOneWidget,
    );
    expect(find.text('keyring unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
