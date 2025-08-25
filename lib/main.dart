import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Allow normal and inverted portrait as well as both landscape orientations.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  final settings = SettingsService();
  runApp(TwoFactorAuthApp(settings: settings));
}

class TwoFactorAuthApp extends StatelessWidget {
  final SettingsService settings;
  const TwoFactorAuthApp({required this.settings, super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '2FA Manager UI',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.white,
      ),
  home: HomePage(settings: settings),
    );
  }
}
