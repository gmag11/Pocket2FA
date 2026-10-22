import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/screens/home_screen.dart';
import 'package:pocket2fa/screens/settings_screen.dart';
import 'package:pocket2fa/services/settings_service.dart';

import '../helpers/fakes/fake_settings_storage.dart';
import '../helpers/pump.dart';

const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pocket2fa_home_');
    messenger.setMockMethodCallHandler(_pathChannel, (call) async {
      return tempDir.path;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_pathChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('starts with empty storage without errors', (tester) async {
    final storage = FakeSettingsStorage();
    final settings = SettingsService(storage: storage);
    await settings.reloadFromStorage();

    await pumpApp(tester, HomePage(settings: settings), settings: settings);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.textContaining('Welcome to Pocket2FA'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('About'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(HomePage), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
