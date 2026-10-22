import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocket2fa/models/account_entry.dart';
import 'package:pocket2fa/models/server_connection.dart';
import 'package:pocket2fa/screens/home_manage_mode.dart';
import 'package:pocket2fa/screens/home_server_manager.dart';
import 'package:pocket2fa/services/api_service.dart';

import '../../helpers/fixtures/api_test_harness.dart';
import '../../helpers/fixtures/server_connection_fixture.dart';
import '../../helpers/pump.dart';
import '../../helpers/reset.dart';

class MockHomeServerManager extends Mock implements HomeServerManager {}

AccountEntry _account({
  required int id,
  String service = 'GitHub',
  bool isBorrowed = false,
}) => AccountEntry(
  id: id,
  service: service,
  account: 'alice',
  seed: 'JBSWY3DPEHPK3PXP',
  group: '',
  isBorrowed: isBorrowed,
);

ServerConnection _server(List<AccountEntry> accounts) =>
    serverConnectionFixture(id: 'server-1', accounts: accounts);

void _stubManager(
  MockHomeServerManager manager, {
  required List<AccountEntry> currentItems,
  required List<ServerConnection> servers,
  String? selectedServerId = 'server-1',
}) {
  when(() => manager.currentItems).thenReturn(currentItems);
  when(() => manager.servers).thenReturn(servers);
  when(() => manager.selectedServerId).thenReturn(selectedServerId);
  when(() => manager.persistServersToStorage()).thenAnswer((_) async {});
  when(() => manager.updateServersInMemory(any())).thenReturn(null);
  when(() => manager.updateServerReachability(any())).thenReturn(null);
}

Future<bool?> _deleteThroughUi(
  WidgetTester tester,
  HomeManageMode mode, {
  bool confirm = true,
}) async {
  bool? result;

  await pumpApp(
    tester,
    Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await mode.deleteSelectedAccounts(context);
          },
          child: const Text('delete'),
        ),
      ),
    ),
  );

  await tester.tap(find.text('delete'));
  await tester.pumpAndSettle();

  if (find.byType(AlertDialog).evaluate().isNotEmpty) {
    await tester.tap(find.text(confirm ? 'Delete' : 'Cancel'));
    await tester.pumpAndSettle();
  }

  return result;
}

void main() {
  final api = ApiService.instance;

  setUp(() {
    api.close();
    resetLogService();
  });

  tearDown(() {
    api.close();
    resetLogService();
  });

  test('toggles manage mode and clears the selection on exit', () {
    final manager = MockHomeServerManager();
    _stubManager(
      manager,
      currentItems: [_account(id: 1)],
      servers: [
        _server([_account(id: 1)]),
      ],
    );
    final mode = HomeManageMode(manager);
    var notifications = 0;
    mode.addListener(() => notifications++);

    expect(mode.isManageMode, isFalse);

    mode.toggleManageMode();
    mode.toggleAccountSelection(1);
    expect(mode.isManageMode, isTrue);
    expect(mode.selectedAccountIds, {1});
    expect(notifications, 2);

    mode.toggleManageMode();
    expect(mode.isManageMode, isFalse);
    expect(mode.selectedAccountIds, isEmpty);
    expect(notifications, 3);
  });

  test('selects owned accounts but rejects borrowed accounts', () {
    final owned = _account(id: 1);
    final borrowed = _account(id: 2, isBorrowed: true);
    final manager = MockHomeServerManager();
    _stubManager(
      manager,
      currentItems: [owned, borrowed],
      servers: [
        _server([owned, borrowed]),
      ],
    );
    final mode = HomeManageMode(manager);

    mode.toggleAccountSelection(2);
    expect(mode.selectedAccountIds, isEmpty);

    mode.toggleAccountSelection(1);
    expect(mode.selectedAccountIds, {1});

    mode.toggleAccountSelection(1);
    expect(mode.selectedAccountIds, isEmpty);
  });

  testWidgets('does nothing without a selection', (tester) async {
    final manager = MockHomeServerManager();
    _stubManager(
      manager,
      currentItems: [_account(id: 1)],
      servers: [
        _server([_account(id: 1)]),
      ],
    );
    final mode = HomeManageMode(manager);

    final result = await _deleteThroughUi(tester, mode);

    expect(result, isFalse);
    verifyNever(() => manager.persistServersToStorage());
  });

  testWidgets('keeps the selection when deletion is cancelled', (tester) async {
    final account = _account(id: 1);
    final manager = MockHomeServerManager();
    _stubManager(
      manager,
      currentItems: [account],
      servers: [
        _server([account]),
      ],
    );
    final mode = HomeManageMode(manager);
    mode.toggleAccountSelection(1);

    final result = await _deleteThroughUi(tester, mode, confirm: false);

    expect(result, isFalse);
    expect(mode.selectedAccountIds, {1});
    verifyNever(() => manager.updateServersInMemory(any()));
  });

  testWidgets('removes a local-only account without a request', (tester) async {
    final local = _account(id: 0);
    final manager = MockHomeServerManager();
    _stubManager(
      manager,
      currentItems: [local],
      servers: [
        _server([local]),
      ],
    );
    final mode = HomeManageMode(manager);
    mode.toggleAccountSelection(0);
    api.close();

    final result = await _deleteThroughUi(tester, mode);

    expect(result, isTrue);
    expect(mode.selectedAccountIds, isEmpty);
    verify(() => manager.persistServersToStorage()).called(1);
    final captured = verify(() => manager.updateServersInMemory(captureAny()))
        .captured;
    expect((captured.last as List<ServerConnection>).single.accounts, isEmpty);
  });

  testWidgets('reports a missing selected server', (tester) async {
    final account = _account(id: 1);
    final manager = MockHomeServerManager();
    _stubManager(
      manager,
      currentItems: [account],
      servers: [
        _server([account]),
      ],
      selectedServerId: 'missing',
    );
    final mode = HomeManageMode(manager);
    mode.toggleAccountSelection(1);

    final result = await _deleteThroughUi(tester, mode);

    expect(result, isFalse);
    verify(() => manager.updateServerReachability(false)).called(1);
    expect(find.text('No server selected'), findsOneWidget);
  });

  testWidgets('keeps a deleted marker when the API is not ready', (
    tester,
  ) async {
    final account = _account(id: 1);
    final manager = MockHomeServerManager();
    _stubManager(
      manager,
      currentItems: [account],
      servers: [
        _server([account]),
      ],
    );
    final mode = HomeManageMode(manager);
    mode.toggleAccountSelection(1);
    api.close();

    final result = await _deleteThroughUi(tester, mode);

    expect(result, isTrue);
    verify(() => manager.updateServerReachability(false)).called(1);
    final captured = verify(() => manager.updateServersInMemory(captureAny()))
        .captured;
    final updated = (captured.first as List<ServerConnection>).single;
    expect(updated.accounts.single.deleted, isTrue);
    expect(updated.accounts.single.synchronized, isFalse);
  });

  testWidgets('removes the account after a successful API delete', (
    tester,
  ) async {
    final account = _account(id: 1);
    final server = _server([account]);
    api.setServer(server, enableLogging: false);
    final harness = ApiTestHarness(api.dio);
    harness.adapter.onDelete('twofaccounts', (mock) => mock.reply(204, null));

    final manager = MockHomeServerManager();
    _stubManager(manager, currentItems: [account], servers: [server]);
    final mode = HomeManageMode(manager);
    mode.toggleAccountSelection(1);

    final result = await _deleteThroughUi(tester, mode);

    expect(result, isTrue);
    expect(harness.lastRequest.queryParameters, {'ids': '1'});
    verify(() => manager.updateServerReachability(true)).called(1);
    final captured = verify(() => manager.updateServersInMemory(captureAny()))
        .captured;
    expect((captured.last as List<ServerConnection>).single.accounts, isEmpty);
  });
}
