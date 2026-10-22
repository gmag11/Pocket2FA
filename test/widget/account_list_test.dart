import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/models/account_entry.dart';
import 'package:pocket2fa/screens/account_list.dart';
import 'package:pocket2fa/services/settings_service.dart';

import '../helpers/fakes/fake_settings_storage.dart';
import '../helpers/pump.dart';

AccountEntry _account({
  required int id,
  required String service,
  required String account,
  String group = 'Work',
  bool deleted = false,
  bool isBorrowed = false,
}) {
  return AccountEntry(
    id: id,
    service: service,
    account: account,
    seed: 'JBSWY3DPEHPK3PXP',
    group: group,
    otpType: 'totp',
    deleted: deleted,
    isBorrowed: isBorrowed,
  );
}

Future<SettingsService> _settings(FakeSettingsStorage storage) async {
  final service = SettingsService(storage: storage);
  await service.reloadFromStorage();
  return service;
}

Future<void> _pumpList(
  WidgetTester tester, {
  required List<AccountEntry> items,
  required FakeSettingsStorage storage,
  String group = 'All',
  String query = '',
  bool isManageMode = false,
  Set<int> selectedAccountIds = const {},
  ValueChanged<int>? onToggleAccountSelection,
  ValueChanged<AccountEntry>? onEditAccount,
  Future<void> Function()? onRefresh,
}) async {
  final settings = await _settings(storage);
  await pumpApp(
    tester,
    Scaffold(
      body: AccountList(
        selectedGroup: group,
        searchQuery: query,
        settings: settings,
        items: items,
        onRefresh: onRefresh,
        isManageMode: isManageMode,
        selectedAccountIds: selectedAccountIds,
        onToggleAccountSelection: onToggleAccountSelection ?? (_) {},
        onEditAccount: onEditAccount,
      ),
    ),
    settings: settings,
  );
  await tester.pump();
}

Future<void> _disposeList(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

FakeSettingsStorage _storageWithServer() => FakeSettingsStorage(
  initialValues: {
    'servers': [
      {
        'id': 'server-1',
        'name': 'Server',
        'url': 'https://example.test',
        'apiKey': 'key',
        'accounts': [],
        'user_email': 'user@example.test',
      },
    ],
  },
);

void main() {
  testWidgets('shows the no-server state and add-server action', (
    tester,
  ) async {
    await _pumpList(tester, items: const [], storage: FakeSettingsStorage());

    expect(find.textContaining('Welcome to Pocket2FA'), findsOneWidget);
    expect(find.text('Add Server'), findsOneWidget);
  });

  testWidgets('shows the no-accounts state when servers exist', (tester) async {
    await _pumpList(tester, items: const [], storage: _storageWithServer());

    expect(find.text('No accounts found'), findsOneWidget);
    expect(find.text('Add Server'), findsNothing);
  });

  testWidgets('filters by group and search and drops deleted entries', (
    tester,
  ) async {
    final items = [
      _account(id: 1, service: 'GitHub', account: 'alice', group: 'Work'),
      _account(id: 2, service: 'GitLab', account: 'bob', group: 'Personal'),
      _account(
        id: 3,
        service: 'Deleted',
        account: 'gone',
        group: 'Work',
        deleted: true,
      ),
    ];
    final storage = _storageWithServer();

    await _pumpList(tester, items: items, storage: storage);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('GitLab'), findsOneWidget);
    expect(find.text('Deleted'), findsNothing);

    await _pumpList(tester, items: items, storage: storage, group: 'Work');
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('GitLab'), findsNothing);

    await _pumpList(tester, items: items, storage: storage, query: 'gitl');
    expect(find.text('GitLab'), findsOneWidget);
    expect(find.text('GitHub'), findsNothing);

    await _pumpList(tester, items: items, storage: storage, query: 'zzz');
    expect(find.text('No results'), findsOneWidget);

    await _disposeList(tester);
  });

  testWidgets('uses a grid on a wide surface', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpList(
      tester,
      items: [
        _account(id: 1, service: 'GitHub', account: 'alice'),
        _account(id: 2, service: 'GitLab', account: 'bob'),
      ],
      storage: _storageWithServer(),
    );

    expect(find.byType(GridView), findsOneWidget);

    await _disposeList(tester);
  });

  testWidgets('wires manage-mode selection and editing for owned accounts', (
    tester,
  ) async {
    final items = [
      _account(id: 1, service: 'GitHub', account: 'alice'),
      _account(id: 2, service: 'GitLab', account: 'bob', isBorrowed: true),
    ];
    var toggled = -1;
    AccountEntry? edited;

    await _pumpList(
      tester,
      items: items,
      storage: _storageWithServer(),
      isManageMode: true,
      selectedAccountIds: {1},
      onToggleAccountSelection: (id) => toggled = id,
      onEditAccount: (entry) => edited = entry,
    );

    expect(find.byType(Checkbox), findsOneWidget);
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(toggled, 1);

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pump();
    expect(edited?.id, 1);

    await _disposeList(tester);
  });

  testWidgets('invokes the refresh callback', (tester) async {
    var refreshed = 0;

    await _pumpList(
      tester,
      items: [_account(id: 1, service: 'GitHub', account: 'alice')],
      storage: _storageWithServer(),
      onRefresh: () async => refreshed++,
    );

    final indicator = tester.state<RefreshIndicatorState>(
      find.byType(RefreshIndicator),
    );
    final refreshFuture = indicator.show();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await refreshFuture;
    await tester.pump();

    expect(refreshed, 1);

    await _disposeList(tester);
  });
}
