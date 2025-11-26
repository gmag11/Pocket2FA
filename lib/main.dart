import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'services/settings_service.dart';
import 'services/settings_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Allow normal and inverted portrait as well as both landscape orientations.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final storage = SettingsStorage();
  await storage.init();

  final settings = SettingsService(storage: storage);
  runApp(Pocket2FA(settings: settings));
}

class Pocket2FA extends StatelessWidget {
  final SettingsService settings;
  const Pocket2FA({required this.settings, super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return MaterialApp(
          onGenerateTitle: (context) =>
              AppLocalizations.of(context)?.appTitle ?? 'Pocket2FA',
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            brightness: Brightness.light,
            scaffoldBackgroundColor: Colors.white,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
          themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: HomePage(settings: settings),
        );
      },
    );
  }
}
