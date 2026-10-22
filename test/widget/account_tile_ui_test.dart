import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/models/account_entry.dart';
import 'package:pocket2fa/services/settings_service.dart';
import 'package:pocket2fa/widgets/account_tile.dart';
import 'package:pocket2fa/widgets/account_tile_hotp.dart';
import 'package:pocket2fa/widgets/account_tile_totp.dart';
import 'package:pocket2fa/widgets/account_tile_ui.dart';

import '../helpers/fakes/fake_settings_storage.dart';
import '../helpers/pump.dart';

const _tinyPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

AccountEntry _item({
  String service = 'GitHub',
  String account = 'user',
  String? localIcon,
  bool isBorrowed = false,
  bool synchronized = true,
  String? otpType = 'totp',
  String seed = 'JBSWY3DPEHPK3PXP',
}) {
  return AccountEntry(
    id: 1,
    service: service,
    account: account,
    seed: seed,
    group: 'Test',
    otpType: otpType,
    localIcon: localIcon,
    isBorrowed: isBorrowed,
    synchronized: synchronized,
  );
}

Future<SettingsService> _settings({
  CodeFormat format = CodeFormat.spaced3,
}) async {
  final service = SettingsService(storage: FakeSettingsStorage());
  await service.reloadFromStorage();
  await service.setFormat(format);
  return service;
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pocket2fa_tile_ui_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('service avatar', () {
    testWidgets('uses the first service initial', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: AccountTileUi.buildServiceAvatar(
            _item(service: 'github'),
            Colors.blue,
          ),
        ),
      );

      expect(find.text('G'), findsOneWidget);
    });

    testWidgets('falls back to the account initial when service is empty', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Scaffold(
          body: AccountTileUi.buildServiceAvatar(
            _item(service: '', account: 'alice'),
            Colors.blue,
          ),
        ),
      );

      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('falls back to a question mark when both names are empty', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Scaffold(
          body: AccountTileUi.buildServiceAvatar(
            _item(service: '', account: ''),
            Colors.blue,
          ),
        ),
      );

      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('loads non-SVG local icons through FileImage', (tester) async {
      final icon = File('${tempDir.path}/icon.png')
        ..writeAsBytesSync(base64Decode(_tinyPng));

      await pumpApp(
        tester,
        Scaffold(
          body: AccountTileUi.buildServiceAvatar(
            _item(localIcon: icon.path),
            Colors.blue,
          ),
        ),
      );

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.backgroundImage, isA<FileImage>());
    });

    testWidgets('loads SVG local icons through SvgPicture', (tester) async {
      final icon = File('${tempDir.path}/icon.svg')
        ..writeAsStringSync(
          '<svg xmlns="http://www.w3.org/2000/svg" width="15%" height="15%" '
          'viewBox="0 0 10 10"><rect width="100%" height="100%" '
          'fill="#00C853"/></svg>',
        );

      await tester.runAsync(() async {
        await pumpApp(
          tester,
          Scaffold(
            body: AccountTileUi.buildServiceAvatar(
              _item(localIcon: icon.path),
              Colors.blue,
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();

      expect(find.byType(SvgPicture), findsOneWidget);
    });

    testWidgets('falls back to the initial when the icon cannot be read', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Scaffold(
          body: AccountTileUi.buildServiceAvatar(
            _item(localIcon: '${tempDir.path}/missing.svg'),
            Colors.blue,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('G'), findsOneWidget);
    });
  });

  group('info rows', () {
    testWidgets('shows the service name and its avatar', (tester) async {
      await pumpApp(
        tester,
        Scaffold(body: AccountTileUi.buildServiceInfoRow(_item(), Colors.blue)),
      );

      expect(find.text('GitHub'), findsOneWidget);
      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('shows the account name', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: AccountTileUi.buildAccountInfoRow(
            _item(account: 'alice@example.test'),
          ),
        ),
      );

      expect(find.text('alice@example.test'), findsOneWidget);
    });
  });

  group('shared indicator', () {
    testWidgets('shows nothing for an owned account', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) =>
                AccountTileUi.buildSharedIndicator(context, _item()),
          ),
        ),
      );

      expect(find.byIcon(Icons.people_outline), findsNothing);
    });

    testWidgets('shows the shared tooltip for a borrowed account', (
      tester,
    ) async {
      await pumpApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => AccountTileUi.buildSharedIndicator(
              context,
              _item(isBorrowed: true),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.people_outline), findsOneWidget);
      expect(find.byTooltip('Shared with you'), findsOneWidget);
    });
  });

  group('HOTP controls', () {
    testWidgets('invokes the generate callback', (tester) async {
      var pressed = false;

      await pumpApp(
        tester,
        Scaffold(
          body: Row(
            children: [AccountTileUi.buildHotpButton(() => pressed = true)],
          ),
        ),
      );

      await tester.tap(find.text('Generate'));
      await tester.pump();

      expect(pressed, isTrue);
    });

    testWidgets('formats the code and shows the counter with settings', (
      tester,
    ) async {
      var copied = false;
      final settings = await _settings();

      await pumpApp(
        tester,
        Scaffold(
          body: Row(
            children: [
              AccountTileUi.buildHotpDisplay(
                hotpCode: '123456',
                hotpCounter: 4,
                settings: settings,
                onCopy: () => copied = true,
              ),
            ],
          ),
        ),
        settings: settings,
      );

      expect(find.text('123 456'), findsOneWidget);
      expect(find.text('counter 4'), findsOneWidget);

      await tester.tap(find.text('123 456'));
      await tester.pump();
      expect(copied, isTrue);
    });

    testWidgets('uses compact formatting without settings', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: Row(
            children: [
              AccountTileUi.buildHotpDisplay(
                hotpCode: '123456',
                hotpCounter: null,
                settings: null,
                onCopy: () {},
              ),
            ],
          ),
        ),
      );

      expect(find.text('123456'), findsOneWidget);
      expect(find.textContaining('counter'), findsNothing);
    });
  });

  group('progress dots', () {
    testWidgets('renders ten dots without a controller', (tester) async {
      await pumpApp(
        tester,
        Scaffold(body: AccountTileUi.buildProgressDots(null)),
      );

      expect(find.byType(Container), findsNWidgets(10));
    });

    testWidgets('updates the dots from a live controller', (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 30),
        value: 0.5,
      );
      addTearDown(controller.dispose);

      await pumpApp(
        tester,
        Scaffold(body: AccountTileUi.buildProgressDots(controller)),
      );
      expect(find.byType(Container), findsNWidgets(10));

      controller.value = 0;
      await tester.pump();
      expect(find.byType(Container), findsNWidgets(10));

      controller.value = 1;
      await tester.pump();
      expect(find.byType(Container), findsNWidgets(10));
    });
  });

  group('AccountTile dispatch', () {
    testWidgets('dispatches TOTP entries and disposes their timer', (
      tester,
    ) async {
      await pumpApp(tester, AccountTile(item: _item(otpType: 'totp')));

      expect(find.byType(AccountTileTOTP), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('dispatches HOTP entries and disposes their timer', (
      tester,
    ) async {
      await pumpApp(tester, AccountTile(item: _item(otpType: 'hotp')));

      expect(find.byType(AccountTileHOTP), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('shows the pending-upload badge for unsynchronized entries', (
      tester,
    ) async {
      await pumpApp(tester, AccountTile(item: _item(synchronized: false)));

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
      expect(
        find.byTooltip('Not synchronized (pending upload)'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('does not show the badge for synchronized entries', (
      tester,
    ) async {
      await pumpApp(tester, AccountTile(item: _item()));

      expect(find.byIcon(Icons.cloud_off), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  });
}
