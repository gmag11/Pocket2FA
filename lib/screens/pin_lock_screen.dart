import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/settings_service.dart';
import '../services/settings_storage.dart';

/// Unlock surface shown when the app starts with the PIN lock enabled.
///
/// Two states are supported by the design:
/// - biometric-first: when biometric protection is also enabled, the biometric
///   prompt is started immediately and a "Use PIN" action is offered;
/// - keypad: one dot per digit typed (never the configured length), a numeric
///   keypad, error feedback, an explicit unlock action and the throttle
///   countdown. Hardware keyboard input works on desktop.
class PinLockScreen extends StatefulWidget {
  final SettingsService settings;

  /// Called after the storage has been unlocked, e.g. to reload servers.
  final Future<void> Function()? onUnlocked;

  /// Optional app-bar title (defaults to "PIN lock").
  final String? title;

  const PinLockScreen({
    required this.settings,
    this.onUnlocked,
    this.title,
    super.key,
  });

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

enum _LockMode { biometric, keypad }

class _PinLockScreenState extends State<PinLockScreen> {
  _LockMode _mode = _LockMode.keypad;
  String _entered = '';
  String? _error;
  bool _busy = false;
  Timer? _countdownTimer;
  int _secondsRemaining = 0;
  final FocusNode _keypadFocus = FocusNode();

  static final Map<LogicalKeyboardKey, String> _digitsByKey = {
    LogicalKeyboardKey.digit0: '0',
    LogicalKeyboardKey.digit1: '1',
    LogicalKeyboardKey.digit2: '2',
    LogicalKeyboardKey.digit3: '3',
    LogicalKeyboardKey.digit4: '4',
    LogicalKeyboardKey.digit5: '5',
    LogicalKeyboardKey.digit6: '6',
    LogicalKeyboardKey.digit7: '7',
    LogicalKeyboardKey.digit8: '8',
    LogicalKeyboardKey.digit9: '9',
    LogicalKeyboardKey.numpad0: '0',
    LogicalKeyboardKey.numpad1: '1',
    LogicalKeyboardKey.numpad2: '2',
    LogicalKeyboardKey.numpad3: '3',
    LogicalKeyboardKey.numpad4: '4',
    LogicalKeyboardKey.numpad5: '5',
    LogicalKeyboardKey.numpad6: '6',
    LogicalKeyboardKey.numpad7: '7',
    LogicalKeyboardKey.numpad8: '8',
    LogicalKeyboardKey.numpad9: '9',
  };

  SettingsStorage? get _storage => widget.settings.storage;
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  bool get _biometricAvailable =>
      widget.settings.biometricEnabled &&
      widget.settings.biometricsSupported;

  /// Submission is always explicit; enable it only for a plausible PIN.
  bool get _canSubmit =>
      !_busy &&
      _secondsRemaining <= 0 &&
      _entered.length >= kPinMinLength &&
      _entered.length <= kPinMaxLength;

  @override
  void initState() {
    super.initState();
    if (_biometricAvailable) {
      _mode = _LockMode.biometric;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _authenticateBiometric();
      });
    }
    _secondsRemaining = _secondsLeft(_storage?.pinLockoutRemaining);
    if (_secondsRemaining > 0) _startCountdown();

    // Make the hardware keyboard work immediately on desktop. The request is
    // repeated after the first frame so it also wins over a pending biometric
    // prompt or a focus change caused by building the keypad.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keypadFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _keypadFocus.dispose();
    super.dispose();
  }

  int _secondsLeft(Duration? duration) {
    if (duration == null || duration <= Duration.zero) return 0;
    return (duration.inMilliseconds / 1000).ceil();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = _secondsLeft(_storage?.pinLockoutRemaining);
      setState(() => _secondsRemaining = remaining);
      if (remaining <= 0) {
        timer.cancel();
        _countdownTimer = null;
      }
    });
  }

  Future<void> _authenticateBiometric() async {
    final storage = _storage;
    if (_busy) return;
    if (storage == null) {
      _showKeypad();
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    var ok = false;
    try {
      // With both factors enabled this prompts for biometrics and releases the
      // key on success; with PIN-only it returns false without unlocking.
      ok = await storage.attemptUnlock();
    } catch (e) {
      // local_auth can throw on cancellation/platform errors. Never leave the
      // screen stuck in the biometric state: fall through to the keypad.
      debugPrint('PinLockScreen: biometric unlock failed: $e');
      ok = false;
    }
    if (!mounted) return;

    if (ok) {
      await _completeUnlock();
      return;
    }

    // Failed or cancelled: never dead-end, fall back to the keypad.
    _showKeypad();
  }

  Future<void> _submitPin() async {
    final storage = _storage;
    if (storage == null || _busy || !_canSubmit) return;

    setState(() => _busy = true);
    final ok = await storage.unlockWithPin(_entered);
    if (!mounted) return;

    if (ok) {
      await _completeUnlock();
      return;
    }

    final remaining = storage.pinLockoutRemaining;
    setState(() {
      _busy = false;
      _entered = '';
      _error = remaining > Duration.zero ? null : l10n.pinIncorrect;
      _secondsRemaining = _secondsLeft(remaining);
    });
    if (remaining > Duration.zero) _startCountdown();
  }

  Future<void> _completeUnlock() async {
    _countdownTimer?.cancel();
    // Reload box-backed settings and notify listeners so the parent swaps the
    // lock screen for the regular UI.
    await widget.settings.reloadFromStorage();
    await widget.onUnlocked?.call();
  }

  void _onDigit(String digit) {
    if (_busy || _secondsRemaining > 0) return;
    if (_entered.length >= kPinMaxLength) return;
    setState(() {
      _error = null;
      _entered += digit;
    });
  }

  void _onDelete() {
    if (_busy || _entered.isEmpty) return;
    setState(() {
      _error = null;
      _entered = _entered.substring(0, _entered.length - 1);
    });
  }

  void _showKeypad() {
    setState(() {
      _mode = _LockMode.keypad;
      _error = null;
      _busy = false;
      _secondsRemaining = _secondsLeft(_storage?.pinLockoutRemaining);
    });
    if (_secondsRemaining > 0) _startCountdown();
    _keypadFocus.requestFocus();
  }

  /// Hardware keyboard support for desktop: digits, backspace and Enter.
  ///
  /// `event.character` is used first so layouts that produce a digit (instead
  /// of exposing it as `LogicalKeyboardKey.digitN`) still work; the logical
  /// key map covers the numeric keypad.
  KeyEventResult _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final digit = _digitForKey(event);
    if (digit != null) {
      // Typing a digit from the biometric state (e.g. after a failed prompt)
      // brings up the keypad and starts the PIN immediately.
      if (_mode != _LockMode.keypad) _showKeypad();
      _onDigit(digit);
      return KeyEventResult.handled;
    }

    if (_mode != _LockMode.keypad) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete) {
      _onDelete();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (_canSubmit) _submitPin();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  String? _digitForKey(KeyEvent event) {
    final character = event.character;
    if (character != null && character.length == 1) {
      final code = character.codeUnitAt(0);
      if (code >= 0x30 && code <= 0x39) return character;
    }
    return _digitsByKey[event.logicalKey];
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _keypadFocus,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title ?? l10n.pinLock)),
        body: SafeArea(
          // Keep keyboard focus on the lock screen: otherwise a clicked key
          // could take focus and Enter would activate that key instead of
          // submitting the PIN.
          child: ExcludeFocus(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    if (_mode == _LockMode.biometric)
                      _buildBiometricState()
                    else
                      _buildKeypadState(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBiometricState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.unlockWithBiometrics,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        if (_busy)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          )
        else
          IconButton.filledTonal(
            iconSize: 48,
            padding: const EdgeInsets.all(20),
            tooltip: l10n.useBiometrics,
            onPressed: _authenticateBiometric,
            icon: const Icon(Icons.fingerprint),
          ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _showKeypad,
          child: Text(l10n.usePin),
        ),
      ],
    );
  }

  Widget _buildKeypadState() {
    final lockedOut = _secondsRemaining > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.pinEnter,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_entered.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 40,
          child: Center(
            child: Text(
              lockedOut
                  ? l10n.pinThrottled(_secondsRemaining)
                  : (_error ?? ''),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map(_digitKey).toList(),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 72, height: 68),
            _digitKey('0'),
            SizedBox(
              width: 72,
              height: 68,
              child: IconButton(
                tooltip: l10n.delete,
                onPressed: (_busy || lockedOut) ? null : _onDelete,
                icon: const Icon(Icons.backspace_outlined),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 200,
          height: 44,
          child: FilledButton(
            onPressed: _canSubmit ? _submitPin : null,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.unlock),
          ),
        ),
        if (_biometricAvailable) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: _busy
                ? null
                : () {
                    setState(() => _mode = _LockMode.biometric);
                    _authenticateBiometric();
                  },
            icon: const Icon(Icons.fingerprint),
            label: Text(l10n.useBiometrics),
          ),
        ],
      ],
    );
  }

  Widget _digitKey(String digit) {
    final enabled = !_busy && _secondsRemaining <= 0;
    return SizedBox(
      width: 72,
      height: 68,
      child: TextButton(
        onPressed: enabled ? () => _onDigit(digit) : null,
        style: TextButton.styleFrom(
          shape: const CircleBorder(),
          textStyle: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        child: Text(digit),
      ),
    );
  }
}
