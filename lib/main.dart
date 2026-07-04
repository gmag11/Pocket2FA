import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'l10n/app_localizations.dart';
import 'screens/home_screen.dart';
import 'services/log_service.dart';
import 'services/settings_service.dart';
import 'services/settings_storage.dart';
import 'services/window_geometry_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Use the Android Photo Picker (no READ_MEDIA_IMAGES permission needed).
  if (Platform.isAndroid) {
    final ImagePickerPlatform picker = ImagePickerPlatform.instance;
    if (picker is ImagePickerAndroid) {
      picker.useAndroidPhotoPicker = true;
    }
  }

  // Allow normal and inverted portrait as well as both landscape orientations.
  // Fire-and-forget: awaiting this platform-channel call before runApp()
  // would delay the very first frame (this is especially noticeable on
  // Android, where the channel can still be warming up right after engine
  // attach). The orientation lock is applied as soon as the engine
  // processes it and doesn't need to gate rendering.
  unawaited(SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]));

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    LogService.instance.error('$error\n$stack', name: 'Dart');
    return false;
  };

  LogService.instance.info('App starting', name: 'main');

  // Render the first frame immediately instead of blocking it behind window
  // geometry restoration and encrypted-storage initialization (opening the
  // Hive box can take a noticeable amount of time, and on desktop the
  // window is only made visible after these complete). `_Bootstrap` shows a
  // lightweight placeholder right away and swaps in the real app as soon as
  // those background tasks finish.
  runApp(const _Bootstrap());
}

/// Runs the (potentially slow) startup work — desktop window geometry
/// restoration and opening the encrypted settings/servers storage — after
/// the first Flutter frame is already on screen, then swaps in the real app.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  SettingsService? _settings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final stopwatch = Stopwatch()..start();
    final storage = SettingsStorage();

    // Window geometry restoration and encrypted storage init are
    // independent of each other; run them concurrently rather than in
    // sequence to minimize total startup latency.
    await Future.wait([
      WindowGeometryService.instance.init(),
      storage.init(),
    ]);
    // Timing is always logged (developer.log), regardless of the in-app
    // debug-logging setting, so it can be captured (e.g. via logcat) to
    // pinpoint the real cause of a slow startup on a given device.
    LogService.instance.info(
        'Bootstrap: storage+window init took ${stopwatch.elapsedMilliseconds}ms',
        name: 'main');

    final settings = SettingsService(storage: storage);
    LogService.instance.enabled = settings.debugLoggingEnabled;

    if (mounted) {
      setState(() => _settings = settings);
    }

    // Reveal the desktop window only now that real content is about to be
    // painted, so users never see a blank/black window.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WindowGeometryService.instance.showWindow();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    if (settings == null) {
      // Minimal placeholder shown for the brief moment before storage is
      // ready. Avoids an empty/black window while keeping startup work off
      // the critical path of the first frame.
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }
    return Pocket2FA(settings: settings);
  }
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
          themeMode: settings.themeMode,
          home: HomePage(settings: settings),
        );
      },
    );
  }
}
