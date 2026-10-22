import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/models/account_entry.dart';
import 'package:pocket2fa/models/server_connection.dart';
import 'package:pocket2fa/screens/home_server_manager.dart';
import 'package:pocket2fa/services/api_service.dart';
import 'package:pocket2fa/services/settings_service.dart';

import '../../helpers/fakes/fake_settings_storage.dart';
import '../../helpers/fixtures/server_connection_fixture.dart';
import '../../helpers/reset.dart';

AccountEntry _account({
  required int id,
  String service = 'GitHub',
  String group = 'Work',
  bool deleted = false,
  bool synchronized = true,
  bool isBorrowed = false,
}) {
  return AccountEntry(
    id: id,
    service: service,
    account: 'alice',
    seed: 'JBSWY3DPEHPK3PXP',
    group: group,
    deleted: deleted,
    synchronized: synchronized,
    isBorrowed: isBorrowed,
  );
}

Future<HomeServerManager> _manager(FakeSettingsStorage storage) async {
  final settings = SettingsService(storage: storage);
  await settings.reloadFromStorage();
  return HomeServerManager(settings);
}

FakeSettingsStorage _storage(
  List<ServerConnection> servers, {
  Map<String, dynamic>? selected,
}) {
  final values = <String, dynamic>{
    'servers': servers.map((server) => server.toMap()).toList(),
  };
  if (selected != null) values['selected'] = selected;
  return FakeSettingsStorage(initialValues: values);
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

  test(
    'loads servers, restores the selection and filters deleted accounts',
    () async {
      final server = serverConnectionFixture(
        accounts: [
          _account(id: 1),
          _account(id: 2, deleted: true),
          _account(id: 3, isBorrowed: true),
        ],
      );
      final manager = await _manager(
        _storage(
          [server],
          selected: {'serverId': server.id, 'accountIndex': 2},
        ),
      );

      await manager.loadServers();

      expect(manager.servers, hasLength(1));
      expect(manager.selectedServerId, server.id);
      expect(manager.selectedAccountIndex, 2);
      expect(manager.currentItems.map((a) => a.id), [1, 3]);
    },
  );

  test(
    'handles empty, intentional-empty and cached-fallback storage',
    () async {
      final server = serverConnectionFixture(accounts: [_account(id: 1)]);
      final storage = _storage([server]);
      final manager = await _manager(storage);

      await manager.loadServers();
      expect(manager.servers, hasLength(1));

      await storage.box.delete('servers');
      await manager.loadServers();
      expect(manager.servers, hasLength(1), reason: 'cached fallback');

      await storage.box.put('servers', []);
      await manager.loadServers();
      expect(manager.servers, isEmpty, reason: 'intentional empty list');
    },
  );

  test('falls back to the first server for an unknown selection', () async {
    final first = serverConnectionFixture(id: 'first', name: 'First');
    final second = serverConnectionFixture(id: 'second', name: 'Second');
    final manager = await _manager(
      _storage(
        [first, second],
        selected: {'serverId': 'missing', 'accountIndex': 0},
      ),
    );

    await manager.loadServers();

    expect(manager.selectedServerId, 'first');
    expect(manager.selectedAccountIndex, isNull);
  });

  test('normalizes duplicate pending ids and persists them', () async {
    final server = serverConnectionFixture(
      accounts: [
        _account(id: -1, synchronized: false),
        _account(id: -1, synchronized: false),
      ],
    );
    final storage = _storage([server]);
    final manager = await _manager(storage);

    await manager.loadServers();

    expect(manager.currentItems.map((a) => a.id), [-1, -2]);
    final persisted = storage.values['servers'] as List<dynamic>;
    final persistedServer = ServerConnection.fromMap(
      Map<dynamic, dynamic>.from(persisted.single as Map),
    );
    expect(persistedServer.accounts.map((a) => a.id), [-1, -2]);
  });

  test('selects a server and persists the selection', () async {
    final server = serverConnectionFixture(accounts: [_account(id: 1)]);
    final storage = _storage([server]);
    final manager = await _manager(storage);
    await manager.loadServers();

    expect(await manager.selectServer('missing'), isFalse);
    expect(await manager.selectServer(server.id, accountIndex: 0), isTrue);
    expect(manager.selectedServerId, server.id);
    expect(storage.values['selected'], {
      'serverId': server.id,
      'accountIndex': 0,
    });
  });

  test('persists servers and tolerates locked storage', () async {
    final server = serverConnectionFixture(accounts: [_account(id: 1)]);
    final storage = _storage([server]);
    final manager = await _manager(storage);
    await manager.loadServers();

    await manager.persistServersToStorage();
    expect(storage.values['servers'], isA<List<dynamic>>());

    final locked = FakeSettingsStorage(unlocked: false);
    final lockedManager = await _manager(locked);
    await lockedManager.persistServersToStorage();
    await lockedManager.loadServers();
    expect(lockedManager.servers, isEmpty);
  });

  test(
    'inserts created accounts for existing, new and temporary ids',
    () async {
      final server = serverConnectionFixture(
        accounts: [_account(id: 1, service: 'Old')],
      );
      final manager = await _manager(_storage([server]));
      await manager.loadServers();

      await manager.insertCreatedAccount(_account(id: 1, service: 'Replaced'));
      expect(manager.currentItems.single.service, 'Replaced');

      await manager.insertCreatedAccount(_account(id: 9, service: 'New'));
      expect(manager.currentItems.map((a) => a.service), ['Replaced', 'New']);

      await manager.insertCreatedAccount(_account(id: 0, service: 'Local'));
      final local = manager.currentItems.last;
      expect(local.id, -1);
      expect(local.synchronized, isFalse);
    },
  );

  test(
    'ignores inserted accounts without a selected or matching server',
    () async {
      final empty = await _manager(FakeSettingsStorage());
      await empty.loadServers();
      await empty.insertCreatedAccount(_account(id: 0));
      expect(empty.currentItems, isEmpty);

      final server = serverConnectionFixture();
      final manager = await _manager(_storage([server]));
      await manager.loadServers();
      await manager.insertCreatedAccount(_account(id: 0));
      expect(manager.currentItems, hasLength(1));
    },
  );

  test('adds, updates and replaces accounts in memory', () async {
    final server = serverConnectionFixture(
      accounts: [
        _account(id: 1, service: 'Old'),
        _account(id: 2),
      ],
    );
    final manager = await _manager(_storage([server]));
    await manager.loadServers();

    await manager.updateAccount(_account(id: 1, service: 'Updated'));
    expect(manager.getSelectedServer()!.accounts.first.service, 'Updated');

    await manager.updateAccount(_account(id: 99, service: 'Missing'));
    expect(manager.getSelectedServer()!.accounts, hasLength(2));

    manager.addNewAccount(_account(id: 3, service: 'Added'));
    expect(manager.currentItems.map((a) => a.service), contains('Added'));

    manager.updateServersInMemory([
      serverConnectionFixture(
        accounts: [
          _account(id: 1),
          _account(id: 2, deleted: true),
          _account(id: 3),
        ],
      ),
    ]);
    expect(manager.currentItems.map((a) => a.id), [1, 3]);
  });

  test('adds to the in-memory items when no server is selected', () async {
    final manager = await _manager(FakeSettingsStorage());
    await manager.loadServers();

    manager.addNewAccount(_account(id: 5));

    expect(manager.currentItems.single.id, 5);
    expect(manager.getSelectedServer(), isNull);
  });

  test('computes groups and group keys', () async {
    final server = serverConnectionFixture(
      accounts: [
        _account(id: 1, group: 'Work'),
        _account(id: 2, group: 'Work'),
        _account(id: 3, group: 'Personal'),
        _account(id: 4, group: ''),
      ],
    );
    final manager = await _manager(_storage([server]));
    await manager.loadServers();

    expect(manager.getGroups(), ['All', 'Work', 'Personal']);
    expect(manager.getGroupKey('Work (4)'), 'Work');
    expect(manager.getGroupKey('All'), 'All');
  });

  test('initial connectivity check is a no-op without a selection', () async {
    final manager = await _manager(FakeSettingsStorage());
    await manager.loadServers();

    await manager.initialConnectivityCheck();

    expect(manager.serverReachable, isFalse);
  });
}
