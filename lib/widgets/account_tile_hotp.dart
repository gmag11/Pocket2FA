import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/account_entry.dart';
import '../services/settings_service.dart';
import 'account_tile_otp_service.dart';
import 'account_tile_ui.dart';
import 'account_tile_utils.dart';

class AccountTileHOTP extends StatefulWidget {
  final AccountEntry item;
  final SettingsService? settings;

  const AccountTileHOTP({required this.item, this.settings, super.key});

  @override
  State<AccountTileHOTP> createState() => _AccountTileHOTPState();
}

class _AccountTileHOTPState extends State<AccountTileHOTP> {
  SettingsService? get settings => widget.settings;
  late AccountTileOtpService _otpService;

  @override
  void initState() {
    super.initState();
    _otpService = AccountTileOtpService(
      account: widget.item,
      settings: settings,
      refreshUi: () {
        if (mounted) setState(() {});
      },
      // HOTP no necesita animaciones
      startAnimationCallback: null,
    );
    _otpService.refreshCodes();
  }

  @override
  void didUpdateWidget(covariant AccountTileHOTP oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item) {
      // account changed: recreate service
      _otpService.dispose();
      _otpService = AccountTileOtpService(
        account: widget.item,
        settings: settings,
        refreshUi: () {
          if (mounted) setState(() {});
        },
        startAnimationCallback: null,
      );
      _otpService.refreshCodes();
    }
  }

  @override
  void dispose() {
    _otpService.dispose();
    super.dispose();
  }

  void _copyToClipboard(String code) async {
    if (!mounted) return;
    final trimmed = code.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'offline') {
      final horizontalMargin = MediaQuery.of(context).size.width * 0.12;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Center(child: Text('No code to copy', style: TextStyle(color: Colors.white))),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(horizontalMargin, 0, horizontalMargin, 96),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16.0))),
        backgroundColor: const Color(0xFF666666),
        duration: const Duration(milliseconds: 1500),
      ));
      return;
    }
    final digits = trimmed.replaceAll(RegExp(r'\s+'), '');
    try {
      await Clipboard.setData(ClipboardData(text: digits));
      if (!mounted) return;
      final horizontalMargin = MediaQuery.of(context).size.width * 0.12;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Center(child: Text('Copied to clipboard', style: TextStyle(color: Colors.white))),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(horizontalMargin, 0, horizontalMargin, 96),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16.0))),
        backgroundColor: const Color(0xFF00C853),
        duration: const Duration(milliseconds: 1500),
      ));
    } catch (_) {
      if (!mounted) return;
      final horizontalMargin = MediaQuery.of(context).size.width * 0.12;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Center(child: Text('Error copying to clipboard', style: TextStyle(color: Colors.white))),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(horizontalMargin, 0, horizontalMargin, 96),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16.0))),
        backgroundColor: const Color(0xFFFF0000),
        duration: const Duration(milliseconds: 1500),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AccountTileUtils.getServiceColor(widget.item.service);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final tile = SizedBox(
          height: 70,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 12),
              // Service and account column with new layout
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 6.0, horizontal: 4.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // First row: Avatar and Service
                      AccountTileUi.buildServiceInfoRow(widget.item, color),
                      const SizedBox(height: 4),
                      // Second row: Account
                      AccountTileUi.buildAccountInfoRow(widget.item),
                    ],
                  ),
                ),
              ),

              // HOTP rendering: either button or display
              (() {
                if (_otpService.hotpCode == null) {
                  return AccountTileUi.buildHotpButton(_otpService.requestHotp);
                }

                // When a HOTP has been requested, display it using the same
                // styling and positioning as the main OTP code for consistency.
                return AccountTileUi.buildHotpDisplay(
                  hotpCode: _otpService.hotpCode,
                  hotpCounter: _otpService.hotpCounter,
                  settings: settings,
                  onCopy: () => _copyToClipboard(_otpService.hotpCode ?? ''),
                );
              }()),
            ],
          ),
        );

        if (screenWidth > 1200) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: tile,
            ),
          );
        }

        return tile;
      },
    );
  }
}