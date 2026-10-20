import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/settings_service.dart';
import '../services/settings_storage.dart';

/// How the current factor was verified before changing or disabling the PIN.
class CurrentFactorVerification {
  final bool verifiedByBiometrics;
  const CurrentFactorVerification({required this.verifiedByBiometrics});
}

/// Warning shown before the PIN lock is enabled: forgetting the PIN with no
/// biometric fallback means the local data cannot be recovered.
Future<bool> showPinForgotWarningDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.pinForgotWarningTitle),
      content: Text(l10n.pinForgotWarning),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.continueLabel),
        ),
      ],
    ),
  );
  return accepted == true;
}

/// Asks for a new PIN twice. The length is simply the number of digits typed
/// (4–8); there is no separate length selector.
///
/// Returns the accepted PIN, or null when the user cancels.
Future<String?> showSetPinDialog(
  BuildContext context, {
  required String title,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NewPinDialog(title: title),
  );
}

/// Verifies the current PIN, or biometrics when those are also enabled.
///
/// Returns null when the user cancels; otherwise the verification result.
Future<CurrentFactorVerification?> showCurrentFactorDialog(
  BuildContext context, {
  required SettingsService settings,
  required String title,
}) {
  return showDialog<CurrentFactorVerification>(
    context: context,
    builder: (_) => _CurrentFactorDialog(title: title, settings: settings),
  );
}

class _NewPinDialog extends StatefulWidget {
  final String title;
  const _NewPinDialog({required this.title});

  @override
  State<_NewPinDialog> createState() => _NewPinDialogState();
}

class _NewPinDialogState extends State<_NewPinDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    final pin = _pinController.text;
    final confirmation = _confirmController.text;

    if (!isValidPin(pin)) {
      setState(() => _error = l10n.pinInvalidLength);
      return;
    }
    if (pin != confirmation) {
      setState(() => _error = l10n.pinMismatch);
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pinController,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(kPinMaxLength),
            ],
            decoration: InputDecoration(
              labelText: l10n.pinEnter,
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(kPinMaxLength),
            ],
            decoration: InputDecoration(
              labelText: l10n.pinConfirm,
              counterText: '',
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

class _CurrentFactorDialog extends StatefulWidget {
  final String title;
  final SettingsService settings;
  const _CurrentFactorDialog({
    required this.title,
    required this.settings,
  });

  @override
  State<_CurrentFactorDialog> createState() => _CurrentFactorDialogState();
}

class _CurrentFactorDialogState extends State<_CurrentFactorDialog> {
  final _pinController = TextEditingController();
  String? _error;
  bool _busy = false;

  bool get _biometricsAvailable =>
      widget.settings.biometricEnabled &&
      widget.settings.biometricsSupported;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verifyPin() async {
    final l10n = AppLocalizations.of(context)!;
    final pin = _pinController.text;
    if (pin.isEmpty) {
      setState(() => _error = l10n.pinIncorrect);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final storage = widget.settings.storage;
    final ok = storage != null && await storage.verifyPin(pin);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(
        const CurrentFactorVerification(verifiedByBiometrics: false),
      );
    } else {
      setState(() {
        _busy = false;
        _error = l10n.pinIncorrect;
      });
    }
  }

  Future<void> _verifyBiometrics() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.settings.verifyCurrentFactorWithBiometrics(
      reason: l10n.unlockWithBiometrics,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(
        const CurrentFactorVerification(verifiedByBiometrics: true),
      );
    } else {
      setState(() {
        _busy = false;
        _error = l10n.authenticationFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pinController,
            autofocus: true,
            enabled: !_busy,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(kPinMaxLength),
            ],
            decoration: InputDecoration(
              labelText: l10n.pinCurrent,
              counterText: '',
            ),
            onSubmitted: (_) => _verifyPin(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        if (_biometricsAvailable)
          TextButton.icon(
            onPressed: _busy ? null : _verifyBiometrics,
            icon: const Icon(Icons.fingerprint, size: 18),
            label: Text(l10n.useBiometrics),
          ),
        FilledButton(
          onPressed: _busy ? null : _verifyPin,
          child: Text(l10n.verify),
        ),
      ],
    );
  }
}
