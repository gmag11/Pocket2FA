import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/services/icon_cache_service.dart';

import '../../helpers/fixtures/server_connection_fixture.dart';
import '../../helpers/reset.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('pocket2fa_icon_cache_');
    messenger.setMockMethodCallHandler(_pathProviderChannel, (call) async {
      return tempDir.path;
    });
    resetLogService();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(_pathProviderChannel, null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    resetLogService();
  });

  test('reads a pre-seeded icon from the cache', () async {
    final connection = serverConnectionFixture();
    final file = await IconCacheService.instance.getIconFile(
      connection,
      'foo bar.png',
    );
    await Directory(file.parent.path).create(recursive: true);
    await file.writeAsBytes(const [1, 2, 3, 4, 5]);

    expect(file.path, endsWith('icons/server-1__foo_bar.png'));

    final first = await IconCacheService.instance.getIconBytes(
      connection,
      'foo bar.png',
    );
    expect(first, [1, 2, 3, 4, 5]);

    final second = await IconCacheService.instance.getIconBytes(
      connection,
      'foo bar.png',
    );
    expect(second, [1, 2, 3, 4, 5]);
  });

  test('sanitizes ids and supports evict and clear', () async {
    final connection = serverConnectionFixture(
      id: 'server/id with spaces',
      url: 'https://example.test/',
    );
    final file = await IconCacheService.instance.getIconFile(
      connection,
      'logo icon.png',
    );
    await Directory(file.parent.path).create(recursive: true);
    await file.writeAsBytes(const [9, 8, 7]);

    expect(file.path, endsWith('server_id_with_spaces__logo_icon.png'));
    expect(file.existsSync(), isTrue);

    await IconCacheService.instance.evict(connection, 'logo icon.png');
    expect(file.existsSync(), isFalse);
    await IconCacheService.instance.evict(connection, 'logo icon.png');

    await IconCacheService.instance.clearAll();
    expect(Directory('${tempDir.path}/icons').existsSync(), isFalse);
    await IconCacheService.instance.clearAll();
  });
}
