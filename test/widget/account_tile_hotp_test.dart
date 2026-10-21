import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/models/account_entry.dart';
import 'package:pocket2fa/services/api_service.dart';
import 'package:pocket2fa/services/settings_service.dart';
import 'package:pocket2fa/widgets/account_tile_hotp.dart';
import 'package:pocket2fa/widgets/account_tile_utils.dart';

import '../helpers/fakes/fake_settings_storage.dart';
import '../helpers/fixtures/api_test_harness.dart';
import '../helpers/fixtures/server_connection_fixture.dart';
import '../helpers/pump.dart';
import '../helpers/reset.dart';

const _seed = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';

AccountEntry _account({
  int id = 1,
  String account = 'alice',
  bool isBorrowed = false,
  int? counter = 0,
}) {
  return AccountEntry(
    id: id,
    service: 'Test',
    account: account,
    seed: isBorrowed ? '' : _seed,
    group: '',
    otpType: 'hotp',
    digits: 6,
    counter: counter,
    isBorrowed: isBorrowed,
  );
}

Future<SettingsService> _settings({bool hideOtps = false}) async {
  final service = SettingsService(storage: FakeSettingsStorage());
  await service.reloadFromStorage();
  await service.setHideOtps(hideOtps);
  return service;
}

Future<void> _pumpTile(
  WidgetTester tester,
  AccountEntry item, {
  SettingsService? settings,
  bool isManageMode = false,
  bool isSelected = false,
  VoidCallback? onToggleSelection,
  VoidCallback? onEdit,
}) async {
  await pumpApp(
    tester,
    Builder(
      builder: (context) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: const TextScaler.linear(0.9)),
          child: Scaffold(
            body: AccountTileHOTP(
              item: item,
              settings: settings,
              isManageMode: isManageMode,
              isSelected: isSelected,
              onToggleSelection: onToggleSelection,
              onEdit: onEdit,
            ),
          ),
        );
      },
    ),
    settings: settings,
  );
  await tester.pump();
}

Future<void> _disposeTile(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

Future<void> _requestCode(WidgetTester tester) async {
  await tester.tap(find.text('Generate'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final api = ApiService.instance;
  late TestDefaultBinaryMessenger messenger;
  late List<String> clipboardWrites;

  setUp(() {
    api.close();
    resetLogService();
    clipboardWrites = [];
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        final arguments = call.arguments;
        if (arguments is Map) {
          clipboardWrites.add(arguments['text']?.toString() ?? '');
        }
        return null;
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    api.close();
    resetLogService();
  });

  ApiTestHarness configure() {
    api.setServer(serverConnectionFixture(), enableLogging: false);
    return ApiTestHarness(api.dio);
  }

  void stubSuccess(ApiTestHarness harness) {
    harness.adapter.onGet(
      'twofaccounts/1/otp',
      (server) => server.reply(200, {'password': '123456', 'counter': 7}),
    );
  }

  testWidgets('starts with Generate and requests a code', (tester) async {
    final harness = configure();
    stubSuccess(harness);

    await _pumpTile(tester, _account());

    expect(find.text('Generate'), findsOneWidget);

    await _requestCode(tester);

    expect(find.text('123456'), findsOneWidget);
    expect(find.text('counter 7'), findsOneWidget);
    expect(harness.lastRequest.path, 'twofaccounts/1/otp');

    await _disposeTile(tester);
  });

  testWidgets('copies the generated code', (tester) async {
    final harness = configure();
    stubSuccess(harness);

    await _pumpTile(tester, _account());
    await _requestCode(tester);

    await tester.tap(find.text('123456'));
    await tester.pump();

    expect(clipboardWrites, ['123456']);
    expect(find.text('Copied to clipboard'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 300));
    await _disposeTile(tester);
  });

  testWidgets('reveals a hidden HOTP code for ten seconds', (tester) async {
    final harness = configure();
    stubSuccess(harness);
    final settings = await _settings(hideOtps: true);
    final visible = AccountTileUtils.formatCode(
      '123456',
      settings,
      forceVisible: true,
    );

    await _pumpTile(tester, _account(), settings: settings);
    await _requestCode(tester);

    expect(find.text('••• •••'), findsOneWidget);

    await tester.longPress(find.text('••• •••'));
    await tester.pump();
    expect(find.text(visible), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(find.text(visible), findsNothing);
    expect(find.text('••• •••'), findsOneWidget);

    await _disposeTile(tester);
  });

  testWidgets('clears the generated code after thirty seconds', (tester) async {
    final harness = configure();
    stubSuccess(harness);

    await _pumpTile(tester, _account());
    await _requestCode(tester);
    expect(find.text('123456'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    await tester.pump();

    expect(find.text('Generate'), findsOneWidget);
    expect(find.text('123456'), findsNothing);

    await _disposeTile(tester);
  });

  testWidgets(
    'shows offline on a failed request and clears it after thirty seconds',
    (tester) async {
      final harness = configure();
      harness.adapter.onGet(
        'twofaccounts/1/otp',
        (server) => server.reply(500, {'message': 'failed'}),
      );

      await _pumpTile(tester, _account());
      await _requestCode(tester);

      expect(find.text('offline'), findsOneWidget);
      expect(find.textContaining('counter'), findsNothing);

      await tester.pump(const Duration(seconds: 30));
      await tester.pump();

      expect(find.text('Generate'), findsOneWidget);

      await _disposeTile(tester);
    },
  );

  testWidgets('manage mode shows selection and handles selection and edit', (
    tester,
  ) async {
    var toggles = 0;
    var edits = 0;

    await _pumpTile(
      tester,
      _account(),
      isManageMode: true,
      isSelected: true,
      onToggleSelection: () => toggles++,
      onEdit: () => edits++,
    );

    expect(find.text('Generate'), findsNothing);
    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(toggles, 1);

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pump();
    expect(edits, 1);

    await _disposeTile(tester);
  });

  testWidgets('borrowed accounts hide the manage-mode checkbox', (
    tester,
  ) async {
    await _pumpTile(
      tester,
      _account(isBorrowed: true),
      isManageMode: true,
      onToggleSelection: () {},
      onEdit: () {},
    );

    expect(find.byType(Checkbox), findsNothing);
    expect(find.byIcon(Icons.people_outline), findsOneWidget);

    await _disposeTile(tester);
  });

  testWidgets('wide manage mode uses the 520-wide wrapper', (tester) async {
    tester.view.physicalSize = const Size(1300, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpTile(tester, _account(), isManageMode: true, onEdit: () {});

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedBox && widget.constraints.maxWidth == 520,
      ),
      findsOneWidget,
    );

    await _disposeTile(tester);
  });

  testWidgets('recreates the service when the account changes', (tester) async {
    final settings = await _settings();

    await _pumpTile(tester, _account(account: 'alice'), settings: settings);
    expect(find.text('alice'), findsOneWidget);

    await _pumpTile(tester, _account(account: 'bob'), settings: settings);
    expect(find.text('bob'), findsOneWidget);
    expect(find.text('alice'), findsNothing);

    await _disposeTile(tester);
  });
}
