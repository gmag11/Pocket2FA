import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/screens/log_screen.dart';
import 'package:pocket2fa/screens/settings_screen.dart';
import 'package:pocket2fa/services/settings_service.dart';

import '../helpers/fakes/fake_settings_storage.dart';
import '../helpers/pump.dart';
import '../helpers/reset.dart';

Future<SettingsService> _settings({
  bool pinEnabled = false,
  bool biometricsSupported = false,
}) async {
  final service = SettingsService(
    storage: FakeSettingsStorage(
      pinEnabled: pinEnabled,
      biometricsSupported: biometricsSupported,
    ),
  );
  await service.reloadFromStorage();
  return service;
}

Future<void> _pumpSettings(
  WidgetTester tester,
  SettingsService settings, {
  ThemeData? theme,
}) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final screen = SettingsScreen(settings: settings);
  await pumpApp(
    tester,
    theme == null ? screen : Theme(data: theme, child: screen),
    settings: settings,
  );
}

Finder _tile(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(ListTile));

Finder _switchIn(String title) =>
    find.descendant(of: _tile(title), matching: find.byType(Switch));

void main() {
  setUp(resetLogService);
  tearDown(resetLogService);

  testWidgets('renders the settings sections and current values', (
    tester,
  ) async {
    final settings = await _settings();
    await _pumpSettings(tester, settings);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('GENERAL'), findsOneWidget);
    expect(find.text('SECURITY'), findsOneWidget);
    expect(find.text('SYNCHRONIZATION'), findsOneWidget);
    expect(find.text('DIAGNOSTICS'), findsOneWidget);
    expect(find.text('Code formatting'), findsOneWidget);
    expect(find.text('Hide OTPs on Home screen'), findsOneWidget);
    expect(find.text('Automatic synchronization'), findsOneWidget);
    expect(find.text('Debug Logging'), findsOneWidget);
  });

  testWidgets('changes the theme through the segmented control', (
    tester,
  ) async {
    final settings = await _settings();
    await _pumpSettings(tester, settings);

    await tester.tap(find.byIcon(Icons.dark_mode));
    await tester.pump();

    expect(settings.themeMode, ThemeMode.dark);
  });

  testWidgets('toggles formatting and selects the spacing format', (
    tester,
  ) async {
    final settings = await _settings();
    await _pumpSettings(tester, settings);

    expect(settings.enabled, isTrue);
    expect(settings.format, CodeFormat.spaced3);
    expect(find.text('123 456'), findsOneWidget);
    expect(find.text('12 34 56'), findsOneWidget);

    await tester.tap(_switchIn('Code formatting'));
    await tester.pump();
    expect(settings.enabled, isFalse);
    expect(find.text('123 456'), findsNothing);
    expect(find.text('12 34 56'), findsNothing);

    await tester.tap(_switchIn('Code formatting'));
    await tester.pump();
    expect(settings.enabled, isTrue);

    await tester.tap(find.text('12 34 56'));
    await tester.pump();
    expect(settings.format, CodeFormat.spaced2);

    await tester.tap(find.text('123 456'));
    await tester.pump();
    expect(settings.format, CodeFormat.spaced3);
  });

  testWidgets('shows biometrics unavailable and the enabled PIN row', (
    tester,
  ) async {
    final settings = await _settings(pinEnabled: true);
    await _pumpSettings(tester, settings);

    final biometricSwitch = tester.widget<Switch>(
      _switchIn('Biometric protection'),
    );
    expect(biometricSwitch.onChanged, isNull);
    expect(
      find.byTooltip('Biometrics not available on this device'),
      findsOneWidget,
    );
    expect(find.text('Change PIN'), findsOneWidget);
  });

  testWidgets('toggles hidden OTPs', (tester) async {
    final settings = await _settings();
    await _pumpSettings(tester, settings);

    expect(settings.hideOtps, isFalse);
    await tester.tap(_switchIn('Hide OTPs on Home screen'));
    await tester.pump();

    expect(settings.hideOtps, isTrue);
  });

  testWidgets('toggles synchronization and reveals the interval selector', (
    tester,
  ) async {
    final settings = await _settings();
    await _pumpSettings(tester, settings);

    expect(settings.syncOnOpen, isTrue);
    await tester.tap(_switchIn('Sync when opening application'));
    await tester.pump();
    expect(settings.syncOnOpen, isFalse);

    expect(settings.autoSyncEnabled, isFalse);
    expect(find.byIcon(Icons.add), findsNothing);

    await tester.tap(_switchIn('Automatic synchronization'));
    await tester.pump();
    expect(settings.autoSyncEnabled, isTrue);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byIcon(Icons.remove), findsOneWidget);
  });

  testWidgets('adjusts the automatic sync interval', (tester) async {
    final settings = await _settings();
    await _pumpSettings(tester, settings);
    await tester.tap(_switchIn('Automatic synchronization'));
    await tester.pump();

    expect(find.text('30'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(settings.autoSyncIntervalMinutes, 31);
    expect(find.text('31'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(settings.autoSyncIntervalMinutes, 30);
    expect(find.text('30'), findsOneWidget);
  });

  testWidgets('enables logging and opens the diagnostic log', (tester) async {
    final settings = await _settings();
    await _pumpSettings(tester, settings);

    expect(settings.debugLoggingEnabled, isFalse);
    expect(find.text('View Diagnostic Log'), findsNothing);

    await tester.tap(_switchIn('Debug Logging'));
    await tester.pump();
    expect(settings.debugLoggingEnabled, isTrue);
    expect(find.text('View Diagnostic Log'), findsOneWidget);

    await tester.tap(find.text('View Diagnostic Log'));
    await tester.pumpAndSettle();

    expect(find.byType(LogScreen), findsOneWidget);
  });

  testWidgets('renders with the dark theme', (tester) async {
    final settings = await _settings();
    await _pumpSettings(tester, settings, theme: ThemeData.dark());

    expect(find.text('Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
