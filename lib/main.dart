import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
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
