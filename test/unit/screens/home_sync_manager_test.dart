import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocket2fa/models/account_entry.dart';
import 'package:pocket2fa/models/server_connection.dart';
import 'package:pocket2fa/screens/home_server_manager.dart';
import 'package:pocket2fa/screens/home_sync_manager.dart';
import 'package:pocket2fa/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes/fake_settings_storage.dart';
import '../../helpers/fixtures/server_connection_fixture.dart';
import '../../helpers/reset.dart';

class MockHomeServerManager extends Mock implements HomeServerManager {}

AccountEntry _account({
  required int id,
  bool synchronized = true,
  bool deleted = false,
  bool isBorrowed = false,
}) => AccountEntry(
  id: id,
  service: 'GitHub',
  account: 'alice',
  seed: 'JBSWY3DPEHPK3PXP',
  group: '',
  synchronized: synchronized,
  deleted: deleted,
  isBorrowed: isBorrowed,
);

ServerConnection _server(List<AccountEntry> accounts) =>
    serverConnectionFixture(accounts: accounts);

void _stub(
  MockHomeServerManager manager, {
  List<ServerConnection> servers = const [],
  String? selectedServerId,
  SettingsService? settings,
}) {
  when(() => manager.servers).thenReturn(servers);
  when(() => manager.selectedServerId).thenReturn(selectedServerId);
  when(() => manager.settings).thenReturn(settings ?? SettingsService());
  when(() => manager.loadServers()).thenAnswer((_) async {});
  when(() => manager.updateServerReachability(any())).thenReturn(null);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetLogService();
  });

  tearDown(resetLogService);

  test('updates sync flags and notifications', () {
    final manager = MockHomeServerManager();
    _stub(manager);
    final sync = HomeSyncManager(manager);
    var notifications = 0;
    sync.addListener(() => notifications++);

    expect(sync.isSyncing, isFalse);
    sync.setSyncing(false);
    expect(notifications, 0);

    sync.setSyncing(true);
    expect(sync.isSyncing, isTrue);
    expect(notifications, 1);

    sync.setSuppressFullScreenSyncIndicator(true);
    expect(sync.suppressFullScreenSyncIndicator, isTrue);
  });

  test('detects pending uploads and ignores excluded accounts', () {
    final manager = MockHomeServerManager();
    _stub(
      manager,
      selectedServerId: 'server-1',
      servers: [
        _server([
          _account(id: -1, synchronized: false),
          _account(id: 1),
          _account(id: 2, deleted: true, synchronized: false),
          _account(id: 3, isBorrowed: true, synchronized: false),
        ]),
      ],
    );
    final sync = HomeSyncManager(manager);

    expect(sync.hasPendingUploads, isTrue);

    _stub(manager, selectedServerId: 'server-1', servers: [_server([])]);
    expect(sync.hasPendingUploads, isFalse);

    _stub(manager, servers: []);
    expect(sync.hasPendingUploads, isFalse);
  });

  test('falls back to the first server when the selection is missing', () {
    final manager = MockHomeServerManager();
    _stub(
      manager,
      selectedServerId: 'missing',
      servers: [
        _server([_account(id: 0, synchronized: false)]),
      ],
    );
    final sync = HomeSyncManager(manager);

    expect(sync.hasPendingUploads, isTrue);
  });

  test('pauses and resumes retries only with pending uploads', () async {
    final manager = MockHomeServerManager();
    _stub(
      manager,
      selectedServerId: 'server-1',
      servers: [
        _server([_account(id: -1, synchronized: false)]),
      ],
    );
    final sync = HomeSyncManager(manager);

    sync.setRetryPaused(true);
    await sync.ensurePendingUploads();
    sync.setRetryPaused(false);

    _stub(manager, selectedServerId: 'server-1', servers: [_server([])]);
    await sync.ensurePendingUploads();
  });

  test(
    'force sync and refresh return early without a selection or storage',
    () async {
      final manager = MockHomeServerManager();
      _stub(manager);
      final sync = HomeSyncManager(manager);

      await sync.forceSyncCurrentServer();
      await sync.onRefreshFromPull();
      expect(sync.suppressFullScreenSyncIndicator, isFalse);

      final noStorageSettings = SettingsService();
      _stub(
        manager,
        selectedServerId: 'server-1',
        servers: [
          _server([_account(id: 1)]),
        ],
        settings: noStorageSettings,
      );
      await sync.forceSyncCurrentServer();
      expect(sync.isSyncing, isFalse);

      _stub(
        manager,
        selectedServerId: 'server-1',
        servers: [],
        settings: SettingsService(storage: FakeSettingsStorage()),
      );
      await sync.forceSyncCurrentServer();
      expect(sync.isSyncing, isFalse);
    },
  );
}
