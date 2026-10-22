import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/l10n/app_localizations.dart';
import 'package:pocket2fa/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps [child] inside the app's localization and theme setup.
///
/// The settings service is created per test after stubbing shared preferences,
/// so no platform plugin is reached. Widget tests that need to react to
/// setting changes can pass their own instance through [settings].
Future<SettingsService> pumpApp(
  WidgetTester tester,
  Widget child, {
  SettingsService? settings,
  Locale locale = const Locale('en'),
}) async {
  SharedPreferences.setMockInitialValues({});
  final service = settings ?? SettingsService();

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: child,
    ),
  );

  // Let the settings service finish its asynchronous initial load before the
  // test starts interacting with the widget tree.
  await tester.pump();
  return service;
}
