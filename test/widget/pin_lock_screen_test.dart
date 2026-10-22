import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/l10n/app_localizations_en.dart';
import 'package:pocket2fa/screens/pin_lock_screen.dart';
import 'package:pocket2fa/services/settings_service.dart';

import '../helpers/fakes/fake_settings_storage.dart';
import '../helpers/pump.dart';

class FakePinStorage extends FakeSettingsStorage {
  FakePinStorage({
    this.acceptedPin = '1234',
    this.lockout = Duration.zero,
    this.biometricsOk = false,
    super.initialValues,
    super.pinEnabled = true,
    super.biometricsSupported = false,
  });

  final String acceptedPin;
  final bool biometricsOk;
  final Duration lockout;
  int _lockoutReads = 0;

  @override
  Duration get pinLockoutRemaining {
    if (lockout <= Duration.zero) return Duration.zero;
    final remaining = lockout - Duration(seconds: _lockoutReads);
    _lockoutReads++;
    return remaining > Duration.zero ? remaining : Duration.zero;
  }

  @override
  Future<bool> unlockWithPin(String pin) async => pin == acceptedPin;

  @override
  Future<bool> attemptUnlock() async => biometricsOk;
}

Future<void> _pumpLock(
  WidgetTester tester, {
  FakePinStorage? storage,
  String title = 'Unlock now',
  VoidCallback? onUnlocked,
}) async {
  final pinStorage = storage ?? FakePinStorage();
  final settings = SettingsService(storage: pinStorage);
  await settings.reloadFromStorage();

  await pumpApp(
    tester,
    PinLockScreen(
      settings: settings,
      title: title,
      onUnlocked: onUnlocked == null
          ? null
          : () async {
              onUnlocked();
            },
    ),
    settings: settings,
  );
  await tester.pump();
}

Future<void> _disposeLock(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

Future<void> _pumpUnlock(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('enters digits, deletes and submits the PIN', (tester) async {
    var unlocked = 0;
    await _pumpLock(tester, onUnlocked: () => unlocked++);

    expect(find.text('Unlock now'), findsOneWidget);
    expect(find.text('Enter your PIN'), findsOneWidget);

    await tester.tap(find.text('1'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('3'));
    await tester.pump();

    final unlock = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Unlock'),
    );
    expect(unlock.onPressed, isNull);

    await tester.tap(find.text('4'));
    await tester.pump();
    expect(find.byType(AnimatedContainer), findsNWidgets(4));

    await tester.tap(find.byTooltip('Delete'));
    await tester.pump();
    expect(find.byType(AnimatedContainer), findsNWidgets(3));

    await tester.tap(find.text('4'));
    await tester.pump();
    await tester.tap(find.text('Unlock'));
    await _pumpUnlock(tester);

    expect(unlocked, 1);
    await _disposeLock(tester);
  });

  testWidgets('shows an error for an incorrect PIN', (tester) async {
    await _pumpLock(tester);

    for (final digit in ['0', '0', '0', '0']) {
      await tester.tap(find.text(digit));
    }
    await tester.pump();

    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect PIN'), findsOneWidget);
    expect(find.byType(AnimatedContainer), findsNothing);

    await _disposeLock(tester);
  });

  testWidgets('disables the keypad during the lockout countdown', (tester) async {
    final l10n = AppLocalizationsEn();
    await _pumpLock(
      tester,
      storage: FakePinStorage(lockout: const Duration(seconds: 3)),
    );

    expect(find.text(l10n.pinThrottled(3)), findsOneWidget);
    final one = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '1'),
    );
    expect(one.onPressed, isNull);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text(l10n.pinThrottled(2)), findsOneWidget);
    expect(
      tester.widget<TextButton>(find.widgetWithText(TextButton, '1')).onPressed,
      isNull,
    );

    await _disposeLock(tester);
  });

  testWidgets('unlocks through biometrics when enabled', (tester) async {
    var unlocked = 0;
    final storage = FakePinStorage(
      biometricsOk: true,
      biometricsSupported: true,
      initialValues: {'biometric_protection_enabled': true},
    );

    await _pumpLock(
      tester,
      storage: storage,
      onUnlocked: () => unlocked++,
    );
    await _pumpUnlock(tester);

    expect(unlocked, 1);
  });

  testWidgets('falls back to the keypad when biometrics fail', (tester) async {
    final storage = FakePinStorage(
      biometricsSupported: true,
      initialValues: {'biometric_protection_enabled': true},
    );

    await _pumpLock(tester, storage: storage);
    await tester.pumpAndSettle();

    expect(find.text('Enter your PIN'), findsOneWidget);
    expect(find.text('Use biometrics'), findsOneWidget);

    await _disposeLock(tester);
  });

  testWidgets('supports hardware keys for digits, backspace and enter', (
    tester,
  ) async {
    var unlocked = 0;
    await _pumpLock(tester, onUnlocked: () => unlocked++);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.pump();
    expect(find.byType(AnimatedContainer), findsNWidgets(4));

    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(find.byType(AnimatedContainer), findsNWidgets(3));

    await tester.sendKeyEvent(LogicalKeyboardKey.digit4);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await _pumpUnlock(tester);

    expect(unlocked, 1);
    await _disposeLock(tester);
  });
}
