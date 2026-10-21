import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/models/account_entry.dart';
import 'package:pocket2fa/services/otp_service.dart';
import 'package:pocket2fa/services/settings_service.dart';
import 'package:pocket2fa/widgets/account_tile_totp.dart';
import 'package:pocket2fa/widgets/account_tile_utils.dart';

import '../helpers/clock.dart';
import '../helpers/fakes/fake_settings_storage.dart';
import '../helpers/pump.dart';

const _seed = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ';
final _fixed = utcFromUnixSeconds(59);

AccountEntry _account({
  int id = 1,
  String account = 'alice',
  bool isBorrowed = false,
  int? digits = 8,
  int? period = 30,
}) {
  return AccountEntry(
    id: id,
    service: 'Test',
    account: account,
    seed: isBorrowed ? '' : _seed,
    group: '',
    otpType: 'totp',
    digits: digits,
    period: period,
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
  await withFixedTimeAsync(_fixed, () async {
    await pumpApp(
      tester,
      Scaffold(
        body: AccountTileTOTP(
          item: item,
          settings: settings,
          isManageMode: isManageMode,
          isSelected: isSelected,
          onToggleSelection: onToggleSelection,
          onEdit: onEdit,
        ),
      ),
      settings: settings,
    );
    await tester.pump();
  });
}

Future<void> _disposeTile(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

String _nextCode(AccountEntry item) => withFixedTime(
  _fixed,
  () => OtpService.generateOtp(item, timeOffsetSeconds: 30),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestDefaultBinaryMessenger messenger;
  late List<String> clipboardWrites;
  var failClipboard = false;

  setUp(() {
    clipboardWrites = [];
    failClipboard = false;
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        if (failClipboard) {
          throw PlatformException(code: 'clipboard-failure');
        }
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
  });

  testWidgets('renders service, account, current and next codes', (
    tester,
  ) async {
    final item = _account();
    final next = _nextCode(item);

    await _pumpTile(tester, item);

    expect(find.text('Test'), findsOneWidget);
    expect(find.text('alice'), findsOneWidget);
    expect(find.text('94287082'), findsOneWidget);
    expect(find.text(next), findsOneWidget);

    await _disposeTile(tester);
  });

  testWidgets('copies the current code', (tester) async {
    await _pumpTile(tester, _account());

    await tester.tap(find.text('94287082'));
    await tester.pump();

    expect(clipboardWrites, ['94287082']);
    expect(find.text('Copied to clipboard'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 300));
    await _disposeTile(tester);
  });

  testWidgets('copies the next code', (tester) async {
    final item = _account();
    final next = _nextCode(item);

    await _pumpTile(tester, item);

    await tester.tap(
      find
          .ancestor(of: find.text(next), matching: find.byType(GestureDetector))
          .first,
    );
    await tester.pump();

    expect(clipboardWrites, [next]);
    expect(find.text('Next code copied to clipboard'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 300));
    await _disposeTile(tester);
  });

  testWidgets('shows the no-code message for an offline borrowed account', (
    tester,
  ) async {
    await _pumpTile(tester, _account(id: 0, isBorrowed: true));

    expect(find.text('offline'), findsOneWidget);

    await tester.tap(find.text('offline'));
    await tester.pump();

    expect(find.text('No code to copy'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await _disposeTile(tester);
  });

  testWidgets('shows the clipboard error message when copying fails', (
    tester,
  ) async {
    await _pumpTile(tester, _account());
    failClipboard = true;

    await tester.tap(find.text('94287082'));
    await tester.pump();

    expect(find.text('Error copying to clipboard'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await _disposeTile(tester);
  });

  testWidgets('reveals hidden current and next codes for ten seconds', (
    tester,
  ) async {
    final item = _account();
    final settings = await _settings(hideOtps: true);
    final next = _nextCode(item);
    final currentVisible = AccountTileUtils.formatCode(
      '94287082',
      settings,
      forceVisible: true,
    );
    final nextVisible = AccountTileUtils.formatCode(
      next,
      settings,
      forceVisible: true,
    );

    await _pumpTile(tester, item, settings: settings);

    expect(find.text('••• ••• ••'), findsNWidgets(2));

    await tester.longPress(find.text('••• ••• ••').first);
    await tester.pump();
    expect(find.text(currentVisible), findsOneWidget);
    expect(find.text('••• ••• ••'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(find.text(currentVisible), findsNothing);
    expect(find.text('••• ••• ••'), findsNWidgets(2));

    await tester.longPress(find.text('••• ••• ••').last);
    await tester.pump();
    expect(find.text(nextVisible), findsOneWidget);
    expect(find.text('••• ••• ••'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    expect(find.text(nextVisible), findsNothing);
    expect(find.text('••• ••• ••'), findsNWidgets(2));

    await _disposeTile(tester);
  });

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

  testWidgets('a null edit callback leaves no edit icon on a wide surface', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1300, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpTile(tester, _account(), isManageMode: true);

    expect(find.byIcon(Icons.edit), findsNothing);
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
