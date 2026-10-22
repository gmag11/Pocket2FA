import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/screens/log_screen.dart';
import 'package:pocket2fa/services/log_service.dart';

import '../helpers/pump.dart';
import '../helpers/reset.dart';

void _seedLevels() {
  LogService.instance.enabled = true;
  LogService.instance
    ..debug('debug message', name: 'DebugSource')
    ..info('info message', name: 'InfoSource')
    ..warning('warning message', name: 'WarnSource')
    ..error('error message', name: 'ErrorSource');
}

Future<void> _pumpLog(WidgetTester tester) async {
  await pumpApp(tester, const LogScreen());
}

void main() {
  late TestDefaultBinaryMessenger messenger;
  late List<String> clipboardWrites;

  setUp(() {
    resetLogService();
    clipboardWrites = [];
    messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        final arguments = call.arguments;
        if (arguments is Map) {
          clipboardWrites.add(arguments['text']?.toString() ?? '');
        }
        return null;
      }
      return null;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    resetLogService();
  });

  testWidgets('shows the empty state', (tester) async {
    await _pumpLog(tester);

    expect(find.text('No log entries yet'), findsOneWidget);
  });

  testWidgets('renders every level with its source and message', (
    tester,
  ) async {
    _seedLevels();
    await _pumpLog(tester);

    expect(find.text('DEBUG'), findsOneWidget);
    expect(find.text('INFO'), findsOneWidget);
    expect(find.text('WARN'), findsOneWidget);
    expect(find.text('ERROR'), findsOneWidget);

    expect(find.text('DebugSource'), findsOneWidget);
    expect(find.text('InfoSource'), findsOneWidget);
    expect(find.text('WarnSource'), findsOneWidget);
    expect(find.text('ErrorSource'), findsOneWidget);

    expect(find.text('debug message'), findsOneWidget);
    expect(find.text('info message'), findsOneWidget);
    expect(find.text('warning message'), findsOneWidget);
    expect(find.text('error message'), findsOneWidget);
  });

  testWidgets('filters by level and restores all entries', (tester) async {
    _seedLevels();
    await _pumpLog(tester);

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ERROR').last);
    await tester.pumpAndSettle();

    expect(find.text('error message'), findsOneWidget);
    expect(find.text('debug message'), findsNothing);
    expect(find.text('info message'), findsNothing);
    expect(find.text('warning message'), findsNothing);

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All').last);
    await tester.pumpAndSettle();

    expect(find.text('debug message'), findsOneWidget);
    expect(find.text('info message'), findsOneWidget);
    expect(find.text('warning message'), findsOneWidget);
    expect(find.text('error message'), findsOneWidget);
  });

  testWidgets('copies the report and shows the copied message', (tester) async {
    _seedLevels();
    await _pumpLog(tester);

    await tester.tap(find.byTooltip('Copy to Clipboard'));
    await tester.pump();

    expect(clipboardWrites, hasLength(1));
    expect(clipboardWrites.single, contains('Pocket2FA Diagnostic Log'));
    expect(clipboardWrites.single, contains('debug message'));
    expect(clipboardWrites.single, contains('error message'));
    expect(find.text('Log copied to clipboard'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('cancels and confirms clearing the log', (tester) async {
    _seedLevels();
    await _pumpLog(tester);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    expect(find.text('Clear Log'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('debug message'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();

    expect(find.text('No log entries yet'), findsOneWidget);
    expect(find.text('debug message'), findsNothing);
  });

  testWidgets('scrolls to the bottom with the FAB', (tester) async {
    LogService.instance.enabled = true;
    for (var i = 0; i < 30; i++) {
      LogService.instance.info('entry $i', name: 'Bulk');
    }
    await _pumpLog(tester);

    await tester.tap(find.byTooltip('Scroll to bottom'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });
}
