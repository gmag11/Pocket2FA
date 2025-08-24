import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Allow normal and inverted portrait as well as both landscape orientations.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const TwoFactorAuthApp());
}

class TwoFactorAuthApp extends StatelessWidget {
  const TwoFactorAuthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '2FA Manager UI',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const HomePage(),
    );
  }
}
