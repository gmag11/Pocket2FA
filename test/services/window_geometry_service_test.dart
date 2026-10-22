import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/services/window_geometry_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _windowChannel = MethodChannel('window_manager');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <String>[];

  setUp(() {
    calls.clear();
    SharedPreferences.setMockInitialValues({});
    messenger.setMockMethodCallHandler(_windowChannel, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'isFullScreen':
        case 'isMaximized':
        case 'isMinimized':
          return false;
        case 'getBounds':
          return {'x': 10.0, 'y': 10.0, 'width': 1000.0, 'height': 600.0};
        default:
          return null;
      }
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_windowChannel, null);
  });

  testWidgets('initializes, shows, saves and closes the window', (
    tester,
  ) async {
    final service = WindowGeometryService.instance;

    expect(WindowGeometryService.isSupportedPlatform, isTrue);

    await service.init();
    expect(calls, contains('ensureInitialized'));
    expect(calls, contains('setPreventClose'));
    expect(calls, contains('waitUntilReadyToShow'));
    expect(calls, contains('setBounds'));

    await service.showWindow();
    expect(calls, contains('show'));
    expect(calls, contains('focus'));

    service.onWindowResize();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('window_width'), 1000.0);
    expect(prefs.getDouble('window_height'), 600.0);
    expect(prefs.getBool('window_maximized'), isFalse);

    service.onWindowClose();
    await tester.pump(const Duration(milliseconds: 100));

    expect(calls.where((call) => call == 'setPreventClose').length, 2);
    expect(calls, contains('close'));
  });
}
