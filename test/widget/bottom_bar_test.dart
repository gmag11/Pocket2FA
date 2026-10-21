import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/models/account_entry.dart';
import 'package:pocket2fa/models/server_connection.dart';
import 'package:pocket2fa/screens/bottom_bar.dart';
import 'package:pocket2fa/services/settings_service.dart';

import '../helpers/fakes/fake_settings_storage.dart';
import '../helpers/fixtures/server_connection_fixture.dart';
import '../helpers/pump.dart';

Future<void> _pumpBar(
  WidgetTester tester, {
  List<ServerConnection> servers = const [],
  String? selectedServerId,
  bool serverReachable = true,
  bool isManageMode = false,
  Set<int> selectedAccountIds = const {},
  VoidCallback? onOpenSelector,
  VoidCallback? onToggleManageMode,
  VoidCallback? onDeleteSelected,
}) async {
  final settings = SettingsService(storage: FakeSettingsStorage());
  await settings.reloadFromStorage();

  await pumpApp(
    tester,
    Scaffold(
      body: BottomBar(
        settings: settings,
        servers: servers,
        selectedServerId: selectedServerId,
        selectedAccountIndex: null,
        serverReachable: serverReachable,
        onOpenSelector: onOpenSelector ?? () {},
        isManageMode: isManageMode,
        selectedAccountIds: selectedAccountIds,
        onToggleManageMode: onToggleManageMode ?? () {},
        onDeleteSelected: onDeleteSelected ?? () {},
      ),
    ),
    settings: settings,
  );
}

AccountEntry _account(String service, String account) => AccountEntry(
  id: 1,
  service: service,
  account: account,
  seed: 'JBSWY3DPEHPK3PXP',
  group: '',
);

void main() {
  testWidgets('shows the empty-server summary', (tester) async {
    await _pumpBar(tester);

    expect(find.text('no-server'), findsOneWidget);
  });

  testWidgets('shows the selected server summary and opens the selector', (
    tester,
  ) async {
    var opened = 0;
    final server = serverConnectionFixture();

    await _pumpBar(
      tester,
      servers: [server],
      selectedServerId: server.id,
      onOpenSelector: () => opened++,
    );

    expect(find.text('user@example.test - example.test'), findsOneWidget);
    expect(find.byIcon(Icons.cloud), findsOneWidget);
    expect(find.byTooltip('Online'), findsOneWidget);

    await tester.tap(find.text('user@example.test - example.test'));
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('falls back to the first server for an unknown selection', (
    tester,
  ) async {
    final first = serverConnectionFixture(
      id: 'first',
      name: 'First',
      userEmail: 'first@example.test',
    );
    final second = serverConnectionFixture(
      id: 'second',
      name: 'Second',
      userEmail: 'second@example.test',
    );

    await _pumpBar(
      tester,
      servers: [first, second],
      selectedServerId: 'missing',
    );

    expect(find.text('first@example.test - example.test'), findsOneWidget);
  });

  testWidgets('shows the offline indicator', (tester) async {
    final server = serverConnectionFixture();

    await _pumpBar(
      tester,
      servers: [server],
      selectedServerId: server.id,
      serverReachable: false,
    );

    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(find.byTooltip('Offline'), findsOneWidget);
  });

  testWidgets('manage mode disables Delete without a selection', (
    tester,
  ) async {
    var toggled = 0;

    await _pumpBar(
      tester,
      isManageMode: true,
      onToggleManageMode: () => toggled++,
    );

    final delete = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Delete'),
    );
    expect(delete.onPressed, isNull);

    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(toggled, 1);
  });

  testWidgets('manage mode enables Delete and invokes its callback', (
    tester,
  ) async {
    var deleted = 0;

    await _pumpBar(
      tester,
      isManageMode: true,
      selectedAccountIds: {1},
      onDeleteSelected: () => deleted++,
    );

    final delete = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Delete'),
    );
    expect(delete.onPressed, isNotNull);

    await tester.tap(find.text('Delete'));
    await tester.pump();
    expect(deleted, 1);
  });

  testWidgets('renders a server with accounts without errors', (tester) async {
    final server = serverConnectionFixture(
      accounts: [_account('GitHub', 'alice'), _account('GitLab', 'bob')],
    );

    await _pumpBar(tester, servers: [server], selectedServerId: server.id);

    expect(find.text('user@example.test - example.test'), findsOneWidget);
  });
}
