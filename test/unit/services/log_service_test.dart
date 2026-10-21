import 'dart:io';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/services/log_service.dart';

import '../../helpers/clock.dart';

const _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  // LogService schedules its notifier through SchedulerBinding, so the
  // framework services need a test binding. This is not a platform channel.
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  Directory? tempDir;

  setUp(() {
    messenger.setMockMethodCallHandler(_pathProviderChannel, null);
    LogService.instance.clear();
    LogService.instance.enabled = true;
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(_pathProviderChannel, null);
    if (tempDir != null && tempDir!.existsSync()) {
      tempDir!.deleteSync(recursive: true);
    }
    tempDir = null;
    LogService.instance.clear();
    LogService.instance.enabled = false;
  });

  testWidgets('publishes the entry count after the frame', (tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    expect(LogService.instance.entryCount.value, 0);

    LogService.instance.log('one');
    expect(LogService.instance.entries, hasLength(1));
    expect(LogService.instance.entryCount.value, 0);

    SchedulerBinding.instance.scheduleFrame();
    await tester.pump();

    expect(LogService.instance.entryCount.value, 1);
  });

  test('captured log entries use the fixed clock', () {
    final fixed = DateTime.utc(2026, 10, 21, 12, 0, 0);

    withFixedTime(fixed, () {
      LogService.instance.log('deterministic timestamp');
    });

    expect(LogService.instance.entries, hasLength(1));
    expect(LogService.instance.entries.single.timestamp, fixed);
  });

  test('logging is a no-op when capture is disabled', () {
    LogService.instance.enabled = false;
    LogService.instance.forceCapture = false;

    LogService.instance.log('dropped');

    expect(LogService.instance.entries, isEmpty);
  });

  group('LogEntry', () {
    final timestamp = DateTime.utc(2026, 10, 21, 12, 34, 56);

    test('renders every level tag', () {
      const expected = {
        LogLevel.debug: 'D',
        LogLevel.info: 'I',
        LogLevel.warning: 'W',
        LogLevel.error: 'E',
      };

      for (final entry in expected.entries) {
        final logEntry = LogEntry(
          timestamp: timestamp,
          level: entry.key,
          name: 'Test',
          message: 'message',
        );
        expect(logEntry.levelTag, entry.value);
      }
    });

    test('formats the timestamp, tag, name and message', () {
      final entry = LogEntry(
        timestamp: timestamp,
        level: LogLevel.warning,
        name: 'Settings',
        message: 'storage locked',
      );

      expect(
        entry.toString(),
        '[2026-10-21T12:34:56.000Z][W][Settings] storage locked',
      );
    });
  });

  test('shortcuts record their level and name', () {
    LogService.instance
      ..debug('debug message', name: 'D')
      ..info('info message', name: 'I')
      ..warning('warning message', name: 'W')
      ..error('error message', name: 'E');

    final entries = LogService.instance.entries;
    expect(entries.map((e) => e.level), [
      LogLevel.debug,
      LogLevel.info,
      LogLevel.warning,
      LogLevel.error,
    ]);
    expect(entries.map((e) => e.name), ['D', 'I', 'W', 'E']);
    expect(entries.map((e) => e.message), [
      'debug message',
      'info message',
      'warning message',
      'error message',
    ]);
  });

  test('keeps at most 1000 entries and evicts the oldest', () {
    for (var i = 0; i <= 1000; i++) {
      LogService.instance.log('entry $i');
    }

    final entries = LogService.instance.entries;
    expect(entries, hasLength(1000));
    expect(entries.first.message, 'entry 1');
    expect(entries.last.message, 'entry 1000');
  });

  test('exports a deterministic text report', () {
    final fixed = DateTime.utc(2026, 10, 21, 12, 0, 0);

    final text = withFixedTime(fixed, () {
      LogService.instance
        ..info('first entry', name: 'Alpha')
        ..error('second entry', name: 'Beta');
      return LogService.instance.exportAsText();
    });

    expect(text, contains('Pocket2FA Diagnostic Log'));
    expect(text, contains('Generated: 2026-10-21T12:00:00.000Z'));
    expect(text, contains('Platform: ${Platform.operatingSystem}'));
    expect(text, contains('─' * 60));
    expect(text, contains('[2026-10-21T12:00:00.000Z][I][Alpha] first entry'));
    expect(text, contains('[2026-10-21T12:00:00.000Z][E][Beta] second entry'));
  });

  test('writes the report to the temporary directory', () async {
    tempDir = Directory.systemTemp.createTempSync('pocket2fa_log_test_');
    messenger.setMockMethodCallHandler(_pathProviderChannel, (call) async {
      expect(call.method, 'getTemporaryDirectory');
      return tempDir!.path;
    });
    final fixed = DateTime.utc(2026, 10, 21, 12, 0, 0);
    LogService.instance.info('written entry');

    final file = await withFixedTime(
      fixed,
      () => LogService.instance.exportToFile(),
    );

    expect(file, isNotNull);
    expect(file!.existsSync(), isTrue);
    expect(
      file.path,
      endsWith('pocket2fa_log_${fixed.millisecondsSinceEpoch}.txt'),
    );
    expect(file.readAsStringSync(), contains('written entry'));
  });

  test('returns null and logs when the directory is unavailable', () async {
    messenger.setMockMethodCallHandler(_pathProviderChannel, (call) async {
      throw PlatformException(code: 'unavailable');
    });

    final file = await LogService.instance.exportToFile();

    expect(file, isNull);
    expect(
      LogService.instance.entries.map((e) => e.message),
      contains(startsWith('Failed to export log to file:')),
    );
  });
}
