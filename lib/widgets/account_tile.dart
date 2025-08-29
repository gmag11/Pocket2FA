import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/account_entry.dart';
import '../services/settings_service.dart';
import 'account_tile_animations.dart';
import 'account_tile_otp_service.dart';
import 'account_tile_ui.dart';
import 'account_tile_utils.dart';

class AccountTile extends StatefulWidget {
  final AccountEntry item;
  final SettingsService? settings;

  const AccountTile({required this.item, this.settings, super.key});

  @override
  State<AccountTile> createState() => _AccountTileState();
}

class _AccountTileState extends State<AccountTile>
    with TickerProviderStateMixin {
  SettingsService? get settings => widget.settings;
  late AccountTileAnimations _animations;
  late AccountTileOtpService _otpService;

  @override
  void initState() {
    super.initState();
    _animations = AccountTileAnimations(vsync: this);
    _otpService = AccountTileOtpService(
      account: widget.item,
      settings: settings,
      refreshUi: () {
        if (mounted) setState(() {});
      },
      startAnimationCallback: () {
        final period = widget.item.period ?? 30;
        _animations.startAnimation(period);
      },
    );
    _otpService.refreshCodes();
  }

  @override
  void didUpdateWidget(covariant AccountTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item) {
      // account changed: recreate services
      _otpService.dispose();
      _animations.dispose();
      _otpService = AccountTileOtpService(
        account: widget.item,
        settings: settings,
        refreshUi: () {
          if (mounted) setState(() {});
        },
        startAnimationCallback: () {
          final period = widget.item.period ?? 30;
          _animations.startAnimation(period);
        },
      );
      _animations = AccountTileAnimations(vsync: this);
      _otpService.refreshCodes();
    }
  }

  @override
  void dispose() {
    _otpService.dispose();
    _animations.dispose();
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

              // Right-side area: either show a HOTP request UI that occupies the
              // combined area (next + current + dots), or render the normal three
              // columns for non-HOTP accounts.
              (() {
                final isHotp =
                    (widget.item.otpType ?? 'totp').toLowerCase() == 'hotp';
                if (isHotp) {
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
                }

                // Non-HOTP rendering: nextCode (small), spacer, main code + dots
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 54,
                      height: 60,
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: AnimatedBuilder(
                            animation: _animations.animController ?? Listenable.merge([]),
                            builder: (context, _) {
                              final anim = _animations.animController;
                              final opacity = (anim != null)
                                  ? anim.value.clamp(0.0, 1.0)
                                  : 1.0;
                              return Opacity(
                                  opacity: opacity,
                                  child: Text(AccountTileUtils.formatCode(_otpService.nextCode, settings),
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.black)));
                            }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints:
                          const BoxConstraints(minWidth: 100, maxWidth: 110),
                      child: Container(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  settings != null
                                      ? AnimatedBuilder(
                                          animation: settings!,
                                          builder: (context, _) {
                                            return InkWell(
                                              onTap: () => _copyToClipboard(_otpService.currentCode),
                                              child: Text(
                                                  AccountTileUtils.formatCode(_otpService.currentCode, settings),
                                                  style: const TextStyle(
                                                      fontSize: 24,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                            );
                                          },
                                        )
                                      : InkWell(
                                          onTap: () => _copyToClipboard(_otpService.currentCode),
                                          child: Text(AccountTileUtils.formatCode(_otpService.currentCode, null),
                                              style: const TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.w700)),
                                        ),
                                  const SizedBox(width: 8),
                                  if ((widget.item.otpType ?? 'totp')
                                          .toLowerCase() ==
                                      'hotp')
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4.0),
                                      child: Tooltip(
                                        message:
                                            'HOTP deshabilitado hasta sincronización',
                                        child: Icon(Icons.block,
                                            size: 18,
                                            color: Colors.grey.shade500),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AccountTileUi.buildProgressDots(_animations.animController),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
