import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/models/account_entry.dart';
import 'package:pocket2fa/models/group_entry.dart';
import 'package:pocket2fa/models/server_connection.dart';
import 'package:pocket2fa/services/api_service.dart';
import 'package:pocket2fa/services/sync_service.dart';

import '../../helpers/fakes/fake_settings_storage.dart';
import '../../helpers/fixtures/api_test_harness.dart';
import '../../helpers/reset.dart';

ServerConnection _server({
  String id = 'server-1',
  String name = 'Test Server',
  String url = 'http://example.test',
  String apiKey = 'test-api-key',
  List<AccountEntry> accounts = const [],
  List<GroupEntry>? groups,
  bool allowSelfSigned = false,
}) {
  return ServerConnection(
    id: id,
    name: name,
    url: url,
    apiKey: apiKey,
    accounts: accounts,
    userEmail: 'user@example.test',
    groups: groups,
    allowSelfSigned: allowSelfSigned,
  );
}

AccountEntry _account({
  int id = 1,
  String service = 'Bank',
  String account = 'alice',
  String seed = 'JBSWY3DPEHPK3PXP',
  String group = '',
  int? groupId,
  String? otpType = 'totp',
  int? digits = 6,
  String? algorithm = 'sha1',
  int? period = 30,
  int? counter,
  String? icon,
  String? localIcon,
  bool synchronized = true,
  bool deleted = false,
  bool isBorrowed = false,
}) {
  return AccountEntry(
    id: id,
    service: service,
    account: account,
    seed: seed,
    group: group,
    groupId: groupId,
    otpType: otpType,
    digits: digits,
    algorithm: algorithm,
    period: period,
    counter: counter,
    icon: icon,
    localIcon: localIcon,
    synchronized: synchronized,
    deleted: deleted,
    isBorrowed: isBorrowed,
  );
}

FakeSettingsStorage _storage({
  Map<dynamic, dynamic>? initialValues,
  bool unlocked = true,
}) {
  return FakeSettingsStorage(initialValues: initialValues, unlocked: unlocked);
}

Map<dynamic, dynamic> _storedServers(ServerConnection server) {
  return {
    'servers': [server.toMap()],
  };
}

/// A cancel token that reports cancellation without failing the in-flight
/// request, so a test can arm it from a response interceptor.
class _LateCancelToken extends CancelToken {
  bool armed = false;

  @override
  bool get isCancelled => armed || super.isCancelled;
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

  ApiTestHarness configure(ServerConnection server) {
    api.setServer(server, enableLogging: false);
    return ApiTestHarness(api.dio, matchMethod: true);
  }

  ApiTestHarness configureFetch(
    ServerConnection server, {
    List<dynamic> groups = const [],
    List<dynamic> accounts = const [],
  }) {
    final harness = configure(server);
    harness.adapter.onGet('groups', (server) => server.reply(200, groups));
    harness.adapter.onGet(
      'twofaccounts',
      (server) => server.reply(200, accounts),
    );
    return harness;
  }

  group('syncIfNeeded', () {
    test('skips a recent non-forced sync without a request', () async {
      final server = _server();
      final storage = _storage(
        initialValues: {'last_sync_server-1': DateTime.now().toIso8601String()},
      );

      final result = await SyncService.instance.syncIfNeeded(server, storage);

      expect(result, {
        'skipped': true,
        'success': true,
        'downloaded': 0,
        'failed': 0,
        'message': 'Skipped (throttled)',
      });
      expect(api.isReady, isFalse);
    });

    test('proceeds after a recent forced sync', () async {
      final server = _server();
      final harness = configureFetch(server);
      final storage = _storage(
        initialValues: {
          'last_sync_server-1': DateTime.now().toIso8601String(),
          'last_sync_forced_server-1': true,
        },
      );

      final result = await SyncService.instance.syncIfNeeded(server, storage);

      expect(result['success'], isTrue);
      expect(result['skipped'], isFalse);
      expect(harness.requests, isNotEmpty);
      expect(storage.values['last_sync_forced_server-1'], isFalse);
    });

    test('proceeds when the last sync is older than the throttle', () async {
      final server = _server();
      final harness = configureFetch(server);
      final storage = _storage(
        initialValues: {
          'last_sync_server-1': DateTime.now()
              .subtract(const Duration(minutes: 20))
              .toIso8601String(),
        },
      );

      final result = await SyncService.instance.syncIfNeeded(server, storage);

      expect(result['success'], isTrue);
      expect(harness.requests, isNotEmpty);
    });

    test('proceeds when the last sync timestamp is corrupt', () async {
      final server = _server();
      final harness = configureFetch(server);
      final storage = _storage(
        initialValues: {'last_sync_server-1': 'not-a-date'},
      );

      final result = await SyncService.instance.syncIfNeeded(server, storage);

      expect(result['success'], isTrue);
      expect(harness.requests, isNotEmpty);
    });

    test('proceeds when the last sync timestamp is not a string', () async {
      final server = _server();
      final harness = configureFetch(server);
      final storage = _storage(initialValues: {'last_sync_server-1': 12345});

      final result = await SyncService.instance.syncIfNeeded(server, storage);

      expect(result['success'], isTrue);
      expect(harness.requests, isNotEmpty);
    });

    test('proceeds when there is no last sync timestamp', () async {
      final server = _server();
      final harness = configureFetch(server);
      final storage = _storage();

      final result = await SyncService.instance.syncIfNeeded(server, storage);

      expect(result['success'], isTrue);
      expect(harness.requests, isNotEmpty);
    });

    test('proceeds when storage is locked and cannot be persisted', () async {
      final server = _server();
      final harness = configureFetch(server);
      final storage = _storage(unlocked: false);

      final result = await SyncService.instance.syncIfNeeded(server, storage);

      expect(result['success'], isTrue);
      expect(harness.requests, isNotEmpty);
      expect(storage.values.containsKey('last_sync_server-1'), isFalse);
    });
  });

  group('forceSync fetch and persistence', () {
    test(
      'fetches groups and accounts, maps groups and replaces the server',
      () async {
        final server = _server();
        final storage = _storage(initialValues: _storedServers(server));
        final harness = configureFetch(
          server,
          groups: [
            {'id': 4, 'name': 'Work', 'twofaccounts_count': 1},
          ],
          accounts: [
            {
              'id': 5,
              'service': 'Bank',
              'account': 'alice',
              'secret': 'JBSWY3DPEHPK3PXP',
              'group': '',
              'group_id': 4,
              'otp_type': 'totp',
            },
          ],
        );

        final result = await SyncService.instance.forceSync(server, storage);

        expect(result['skipped'], isFalse);
        expect(result['success'], isTrue);
        expect(result['downloaded'], 0);
        expect(result['failed'], 0);
        expect(result['skipped_count'], 0);
        expect(result['iconStatus'], 'all_ok');
        expect(result['message'], 'Sync completed');

        expect(
          harness.requests.map((request) => request.path),
          containsAllInOrder(['groups', 'twofaccounts']),
        );
        expect(harness.lastRequest.path, 'twofaccounts');
        expect(harness.lastRequest.queryParameters, {'withSecret': 'true'});

        final stored = storage.values['servers'] as List<dynamic>;
        expect(stored, hasLength(1));
        final persisted = ServerConnection.fromMap(
          Map<dynamic, dynamic>.from(stored.single as Map),
        );
        expect(persisted.id, server.id);
        expect(persisted.accounts, hasLength(1));
        expect(persisted.accounts.single.id, 5);
        expect(persisted.accounts.single.group, 'Work');
        expect(persisted.groups, hasLength(1));
        expect(persisted.groups!.single.name, 'Work');

        expect(
          DateTime.parse(storage.values['last_sync_server-1'] as String),
          isA<DateTime>(),
        );
        expect(storage.values['last_sync_forced_server-1'], isFalse);
      },
    );

    test(
      'falls back to stored groups when the groups response is not a list',
      () async {
        final group = GroupEntry(id: 4, name: 'Work', twofaccountsCount: 1);
        final server = _server(groups: [group]);
        final storage = _storage(initialValues: _storedServers(server));
        final harness = configure(server);
        harness.adapter.onGet('groups', (server) => server.reply(200, {}));
        harness.adapter.onGet(
          'twofaccounts',
          (server) => server.reply(200, [
            {
              'id': 5,
              'service': 'Bank',
              'account': 'alice',
              'group': '',
              'group_id': 4,
            },
          ]),
        );

        final result = await SyncService.instance.forceSync(server, storage);

        expect(result['success'], isTrue);
        final stored = storage.values['servers'] as List<dynamic>;
        final persisted = ServerConnection.fromMap(
          Map<dynamic, dynamic>.from(stored.single as Map),
        );
        expect(persisted.accounts.single.group, 'Work');
        expect(persisted.groups!.single.name, 'Work');
      },
    );

    test(
      'falls back to stored groups when the groups request throws',
      () async {
        final group = GroupEntry(id: 4, name: 'Work', twofaccountsCount: 1);
        final server = _server(groups: [group]);
        final storage = _storage(initialValues: _storedServers(server));
        final harness = configure(server);
        harness.adapter.onGet(
          'groups',
          (server) => server.throws(
            0,
            DioException(
              requestOptions: RequestOptions(path: 'groups'),
              type: DioExceptionType.connectionError,
            ),
          ),
        );
        harness.adapter.onGet(
          'twofaccounts',
          (server) => server.reply(200, [
            {
              'id': 5,
              'service': 'Bank',
              'account': 'alice',
              'group': '',
              'group_id': 4,
            },
          ]),
        );

        final result = await SyncService.instance.forceSync(server, storage);

        expect(result['success'], isTrue);
        final stored = storage.values['servers'] as List<dynamic>;
        final persisted = ServerConnection.fromMap(
          Map<dynamic, dynamic>.from(stored.single as Map),
        );
        expect(persisted.accounts.single.group, 'Work');
      },
    );

    test(
      'returns a network failure for a non-list accounts response',
      () async {
        final server = _server();
        final storage = _storage(initialValues: _storedServers(server));
        final harness = configureFetch(server);
        harness.adapter.onGet(
          'twofaccounts',
          (server) => server.reply(200, {}),
        );

        final result = await SyncService.instance.forceSync(server, storage);

        expect(result['success'], isFalse);
        expect(result['network_failed'], isTrue);
        expect(result['message'], 'Network failure - no account data fetched');
        expect(storage.values.containsKey('last_sync_server-1'), isFalse);
      },
    );

    test(
      'returns a network failure for an HTTP 500 accounts response',
      () async {
        final server = _server();
        final storage = _storage(initialValues: _storedServers(server));
        final harness = configureFetch(server);
        api.dio.options.validateStatus = (_) => true;
        harness.adapter.onGet(
          'twofaccounts',
          (server) => server.reply(500, {'error': 'boom'}),
        );

        final result = await SyncService.instance.forceSync(server, storage);

        expect(result['success'], isFalse);
        expect(result['network_failed'], isTrue);
        expect(storage.values.containsKey('last_sync_server-1'), isFalse);
      },
    );

    test(
      'returns a network failure when the accounts request throws',
      () async {
        final server = _server();
        final storage = _storage(initialValues: _storedServers(server));
        final harness = configureFetch(server);
        harness.adapter.onGet(
          'twofaccounts',
          (server) => server.throws(
            0,
            DioException(
              requestOptions: RequestOptions(path: 'twofaccounts'),
              type: DioExceptionType.connectionError,
            ),
          ),
        );

        final result = await SyncService.instance.forceSync(server, storage);

        expect(result['success'], isFalse);
        expect(result['network_failed'], isTrue);
        expect(storage.values.containsKey('last_sync_server-1'), isFalse);
      },
    );

    test('filters a fetched account that is still pending deletion', () async {
      final pendingDelete = _account(id: 5, synchronized: false, deleted: true);
      final server = _server(accounts: [pendingDelete]);
      final storage = _storage(initialValues: _storedServers(server));
      final harness = configureFetch(
        server,
        accounts: [
          {'id': 5, 'service': 'Bank', 'account': 'alice'},
        ],
      );
      harness.adapter.onDelete(
        'twofaccounts',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: 'twofaccounts'),
            type: DioExceptionType.connectionError,
          ),
        ),
      );

      final result = await SyncService.instance.forceSync(server, storage);

      expect(result['success'], isTrue);
      final stored = storage.values['servers'] as List<dynamic>;
      final persisted = ServerConnection.fromMap(
        Map<dynamic, dynamic>.from(stored.single as Map),
      );
      expect(persisted.accounts, isEmpty);
      expect(
        harness.requests.any((request) => request.method == 'DELETE'),
        isTrue,
      );
    });

    test(
      'keeps a local-only pending create after a failed upload and fetch',
      () async {
        final pending = _account(
          id: 0,
          service: 'Local',
          account: 'pending',
          synchronized: false,
        );
        final server = _server(accounts: [pending]);
        final storage = _storage(initialValues: _storedServers(server));
        final harness = configureFetch(server);
        harness.adapter.onPost(
          'twofaccounts',
          (server) => server.throws(
            0,
            DioException(
              requestOptions: RequestOptions(path: 'twofaccounts'),
              type: DioExceptionType.connectionError,
            ),
          ),
        );

        final result = await SyncService.instance.forceSync(server, storage);

        expect(result['success'], isTrue);
        final stored = storage.values['servers'] as List<dynamic>;
        final persisted = ServerConnection.fromMap(
          Map<dynamic, dynamic>.from(stored.single as Map),
        );
        expect(persisted.accounts, hasLength(1));
        expect(persisted.accounts.single.id, 0);
        expect(persisted.accounts.single.service, 'Local');
        expect(persisted.accounts.single.synchronized, isFalse);
      },
    );

    test(
      'does not crash or persist timestamps with malformed servers data',
      () async {
        final server = _server();
        final storage = _storage(initialValues: {'servers': 'not-a-list'});
        configureFetch(server);

        final result = await SyncService.instance.forceSync(server, storage);

        expect(result['success'], isTrue);
        expect(storage.values.containsKey('last_sync_server-1'), isFalse);
      },
    );

    test('does not persist timestamps when storage is locked', () async {
      final server = _server();
      final storage = _storage(unlocked: false);
      configureFetch(server);

      final result = await SyncService.instance.forceSync(server, storage);

      expect(result['success'], isTrue);
      expect(storage.values.containsKey('last_sync_server-1'), isFalse);
    });
  });

  group('uploadPendingAccounts', () {
    test(
      'uploads a pending account, merges it and resolves its group',
      () async {
        final pending = _account(
          id: 0,
          service: 'Bank',
          account: 'alice',
          groupId: 4,
          synchronized: false,
        );
        final server = _server(
          accounts: [pending],
          groups: [GroupEntry(id: 4, name: 'Work', twofaccountsCount: 1)],
        );
        final storage = _storage(initialValues: _storedServers(server));
        final harness = configure(server);
        harness.adapter.onPost(
          'twofaccounts',
          (server) => server.reply(201, {
            'id': 10,
            'service': 'ServerBank',
            'account': 'alice',
            'group_id': 4,
          }),
        );

        final uploaded = await SyncService.instance.uploadPendingAccounts(
          server,
          storage,
        );

        expect(uploaded, 1);
        expect(harness.lastRequest.path, 'twofaccounts');
        expect(harness.lastRequest.method, 'POST');
        expect(harness.lastRequest.data, {
          'service': 'Bank',
          'account': 'alice',
          'secret': 'JBSWY3DPEHPK3PXP',
          'otp_type': 'totp',
          'digits': 6,
          'algorithm': 'sha1',
          'period': 30,
          'group_id': 4,
        });

        final stored = storage.values['servers'] as List<dynamic>;
        final persisted = ServerConnection.fromMap(
          Map<dynamic, dynamic>.from(stored.single as Map),
        );
        expect(persisted.accounts, hasLength(1));
        final account = persisted.accounts.single;
        expect(account.id, 10);
        expect(account.service, 'ServerBank');
        expect(account.seed, 'JBSWY3DPEHPK3PXP');
        expect(account.group, 'Work');
        expect(account.groupId, 4);
        expect(account.synchronized, isTrue);
      },
    );

    test('returns zero when the create response has no id', () async {
      final pending = _account(id: 0, synchronized: false);
      final server = _server(accounts: [pending]);
      final storage = _storage(initialValues: _storedServers(server));
      final harness = configure(server);
      harness.adapter.onPost(
        'twofaccounts',
        (server) => server.reply(201, {'service': 'Bank'}),
      );

      final uploaded = await SyncService.instance.uploadPendingAccounts(
        server,
        storage,
      );

      expect(uploaded, 0);
      final stored = storage.values['servers'] as List<dynamic>;
      final persisted = ServerConnection.fromMap(
        Map<dynamic, dynamic>.from(stored.single as Map),
      );
      expect(persisted.accounts.single.id, 0);
      expect(persisted.accounts.single.synchronized, isFalse);
    });

    test('returns zero when the create request fails', () async {
      final pending = _account(id: 0, synchronized: false);
      final server = _server(accounts: [pending]);
      final storage = _storage(initialValues: _storedServers(server));
      final harness = configure(server);
      harness.adapter.onPost(
        'twofaccounts',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: 'twofaccounts'),
            type: DioExceptionType.connectionError,
          ),
        ),
      );

      final uploaded = await SyncService.instance.uploadPendingAccounts(
        server,
        storage,
      );

      expect(uploaded, 0);
      final stored = storage.values['servers'] as List<dynamic>;
      final persisted = ServerConnection.fromMap(
        Map<dynamic, dynamic>.from(stored.single as Map),
      );
      expect(persisted.accounts.single.id, 0);
    });

    test('does nothing when there are no pending accounts', () async {
      final server = _server(accounts: [_account(id: 5)]);
      final storage = _storage(initialValues: _storedServers(server));
      final harness = configure(server);

      final uploaded = await SyncService.instance.uploadPendingAccounts(
        server,
        storage,
      );

      expect(uploaded, 0);
      expect(harness.requests, isEmpty);
    });

    test('returns zero when the server is not in storage', () async {
      final other = _server(id: 'other');
      final storage = _storage(initialValues: _storedServers(other));
      final server = _server();
      configure(server);

      final uploaded = await SyncService.instance.uploadPendingAccounts(
        server,
        storage,
      );

      expect(uploaded, 0);
    });

    test('returns zero when storage is locked', () async {
      final server = _server();
      final storage = _storage(unlocked: false);
      configure(server);

      final uploaded = await SyncService.instance.uploadPendingAccounts(
        server,
        storage,
      );

      expect(uploaded, 0);
      expect(api.isReady, isTrue);
    });

    test('returns zero without crashing on malformed storage', () async {
      final server = _server();
      final storage = _storage(initialValues: {'servers': 'not-a-list'});
      configure(server);

      final uploaded = await SyncService.instance.uploadPendingAccounts(
        server,
        storage,
      );

      expect(uploaded, 0);
    });

    test('returns zero when storage has no servers list', () async {
      final server = _server();
      final storage = _storage();
      final harness = configure(server);

      final uploaded = await SyncService.instance.uploadPendingAccounts(
        server,
        storage,
      );

      expect(uploaded, 0);
      expect(harness.requests, isEmpty);
    });
  });

  group('forceSync pending deletes', () {
    test('deletes a pending tombstone and removes it from storage', () async {
      final tombstone = _account(id: 5, synchronized: false, deleted: true);
      final server = _server(accounts: [tombstone]);
      final storage = _storage(initialValues: _storedServers(server));
      final harness = configure(server);
      harness.adapter.onGet('groups', (server) => server.reply(200, []));
      harness.adapter.onGet(
        'twofaccounts',
        (server) => server.reply(500, {'error': 'offline'}),
      );
      harness.adapter.onDelete(
        'twofaccounts',
        (server) => server.reply(204, null),
      );

      final result = await SyncService.instance.forceSync(server, storage);

      expect(result['network_failed'], isTrue);
      final deleteRequests = harness.requests
          .where((request) => request.method == 'DELETE')
          .toList();
      expect(deleteRequests, hasLength(1));
      expect(deleteRequests.single.queryParameters, {'ids': '5'});

      final stored = storage.values['servers'] as List<dynamic>;
      final persisted = ServerConnection.fromMap(
        Map<dynamic, dynamic>.from(stored.single as Map),
      );
      expect(persisted.accounts, isEmpty);
    });

    test('purges a local-only tombstone without calling DELETE', () async {
      final tombstone = _account(id: 0, synchronized: false, deleted: true);
      final server = _server(accounts: [tombstone]);
      final storage = _storage(initialValues: _storedServers(server));
      final harness = configure(server);
      harness.adapter.onGet('groups', (server) => server.reply(200, []));
      harness.adapter.onGet(
        'twofaccounts',
        (server) => server.reply(500, {'error': 'offline'}),
      );

      final result = await SyncService.instance.forceSync(server, storage);

      expect(result['network_failed'], isTrue);
      expect(
        harness.requests.where((request) => request.method == 'DELETE'),
        isEmpty,
      );
      final stored = storage.values['servers'] as List<dynamic>;
      final persisted = ServerConnection.fromMap(
        Map<dynamic, dynamic>.from(stored.single as Map),
      );
      expect(persisted.accounts, isEmpty);
    });

    test('does not call DELETE when there are no pending deletes', () async {
      final server = _server(accounts: [_account(id: 5)]);
      final storage = _storage(initialValues: _storedServers(server));
      final harness = configureFetch(server);

      final result = await SyncService.instance.forceSync(server, storage);

      expect(result['success'], isTrue);
      expect(
        harness.requests.where((request) => request.method == 'DELETE'),
        isEmpty,
      );
    });
  });

  group('forceSync pending updates', () {
    test(
      'updates an edited account and keeps its group and local icon',
      () async {
        final edited = _account(
          id: 5,
          service: 'Bank',
          account: 'alice',
          groupId: 4,
          localIcon: '/tmp/icon.png',
          synchronized: false,
        );
        final server = _server(
          accounts: [edited],
          groups: [GroupEntry(id: 4, name: 'Work', twofaccountsCount: 1)],
        );
        final storage = _storage(initialValues: _storedServers(server));
        final harness = configure(server);
        harness.adapter.onPut(
          'twofaccounts/5',
          (server) => server.reply(200, {
            'id': 5,
            'service': 'Updated',
            'account': 'alice',
            'group_id': 4,
          }),
        );
        harness.adapter.onGet('groups', (server) => server.reply(200, []));
        harness.adapter.onGet(
          'twofaccounts',
          (server) => server.reply(500, {'error': 'offline'}),
        );

        final result = await SyncService.instance.forceSync(server, storage);

        expect(result['network_failed'], isTrue);
        final put = harness.requests.firstWhere(
          (request) => request.method == 'PUT',
        );
        expect(put.path, 'twofaccounts/5');
        expect(put.data['group_id'], 4);
        expect(put.data['service'], 'Bank');
        expect(put.data['account'], 'alice');
        expect(put.data['otp_type'], 'totp');

        final stored = storage.values['servers'] as List<dynamic>;
        final persisted = ServerConnection.fromMap(
          Map<dynamic, dynamic>.from(stored.single as Map),
        );
        final account = persisted.accounts.single;
        expect(account.id, 5);
        expect(account.service, 'Updated');
        expect(account.group, 'Work');
        expect(account.localIcon, '/tmp/icon.png');
        expect(account.synchronized, isTrue);
      },
    );

    test(
      'leaves the account unchanged when the update response has no id',
      () async {
        final edited = _account(id: 5, service: 'Bank', synchronized: false);
        final server = _server(accounts: [edited]);
        final storage = _storage(initialValues: _storedServers(server));
        final harness = configure(server);
        harness.adapter.onPut(
          'twofaccounts/5',
          (server) => server.reply(200, {'service': 'Updated'}),
        );
        harness.adapter.onGet('groups', (server) => server.reply(200, []));
        harness.adapter.onGet(
          'twofaccounts',
          (server) => server.reply(500, {'error': 'offline'}),
        );

        final result = await SyncService.instance.forceSync(server, storage);

        expect(result['network_failed'], isTrue);
        final stored = storage.values['servers'] as List<dynamic>;
        final persisted = ServerConnection.fromMap(
          Map<dynamic, dynamic>.from(stored.single as Map),
        );
        final account = persisted.accounts.single;
        expect(account.id, 5);
        expect(account.service, 'Bank');
        expect(account.synchronized, isFalse);
      },
    );

    test(
      'leaves the account unchanged when the update request fails',
      () async {
        final edited = _account(id: 5, service: 'Bank', synchronized: false);
        final server = _server(accounts: [edited]);
        final storage = _storage(initialValues: _storedServers(server));
        final harness = configure(server);
        harness.adapter.onPut(
          'twofaccounts/5',
          (server) => server.throws(
            0,
            DioException(
              requestOptions: RequestOptions(path: 'twofaccounts/5'),
              type: DioExceptionType.connectionError,
            ),
          ),
        );
        harness.adapter.onGet('groups', (server) => server.reply(200, []));
        harness.adapter.onGet(
          'twofaccounts',
          (server) => server.reply(500, {'error': 'offline'}),
        );

        final result = await SyncService.instance.forceSync(server, storage);

        expect(result['network_failed'], isTrue);
        final stored = storage.values['servers'] as List<dynamic>;
        final persisted = ServerConnection.fromMap(
          Map<dynamic, dynamic>.from(stored.single as Map),
        );
        final account = persisted.accounts.single;
        expect(account.id, 5);
        expect(account.service, 'Bank');
        expect(account.synchronized, isFalse);
      },
    );
  });

  group('forceSync summaries', () {
    test('reports an all-ok no-icon summary', () async {
      final server = _server(accounts: [_account(id: 5)]);
      final storage = _storage(initialValues: _storedServers(server));
      final harness = configureFetch(
        server,
        accounts: [
          {'id': 5, 'service': 'Bank', 'account': 'alice'},
        ],
      );

      final result = await SyncService.instance.forceSync(server, storage);

      expect(result, {
        'skipped': false,
        'success': true,
        'downloaded': 0,
        'failed': 0,
        'skipped_count': 0,
        'iconStatus': 'all_ok',
        'message': 'Sync completed',
      });
      expect(
        harness.requests.where((request) => request.method == 'GET'),
        isNotEmpty,
      );
    });

    test(
      'stops icon downloads when the token is cancelled after accounts',
      () async {
        final server = _server(accounts: [_account(id: 5, icon: 'icon.png')]);
        final storage = _storage(initialValues: _storedServers(server));
        final harness = configureFetch(
          server,
          accounts: [
            {
              'id': 5,
              'service': 'Bank',
              'account': 'alice',
              'icon': 'icon.png',
            },
          ],
        );
        final token = _LateCancelToken();
        api.dio.interceptors.add(
          InterceptorsWrapper(
            onResponse: (response, handler) {
              if (response.requestOptions.path == 'twofaccounts') {
                token.armed = true;
              }
              handler.next(response);
            },
          ),
        );

        final result = await SyncService.instance.forceSync(
          server,
          storage,
          cancelToken: token,
        );

        expect(result['success'], isTrue);
        expect(result['downloaded'], 0);
        expect(result['failed'], 0);
        expect(result['skipped_count'], 0);
        final stored = storage.values['servers'] as List<dynamic>;
        final persisted = ServerConnection.fromMap(
          Map<dynamic, dynamic>.from(stored.single as Map),
        );
        expect(persisted.accounts.single.icon, 'icon.png');
        expect(
          harness.requests.where((request) => request.method == 'GET'),
          hasLength(2),
        );
      },
    );
  });
}
