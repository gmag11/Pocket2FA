import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../models/account_entry.dart';
import '../services/settings_service.dart';
import 'account_tile_animations.dart';
import 'account_tile_otp_service.dart';
import 'account_tile_ui.dart';
import 'account_tile_utils.dart';

class AccountTileTOTP extends StatefulWidget {
  final AccountEntry item;
  final SettingsService? settings;

  const AccountTileTOTP({required this.item, this.settings, super.key});

  @override
  State<AccountTileTOTP> createState() => _AccountTileTOTPState();
}

class _AccountTileTOTPState extends State<AccountTileTOTP>
    with TickerProviderStateMixin {
  SettingsService? get settings => widget.settings;
  late AccountTileAnimations _animations;
  late AccountTileOtpService _otpService;
  Timer? _revealTimerCurrent;
  Timer? _revealTimerNext;
  bool _revealCurrent = false;
  bool _revealNext = false;

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
  void didUpdateWidget(covariant AccountTileTOTP oldWidget) {
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
  _revealTimerCurrent?.cancel();
  _revealTimerNext?.cancel();
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
        content: const Center(
            child:
                Text('No code to copy', style: TextStyle(color: Colors.white))),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(horizontalMargin, 0, horizontalMargin, 96),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16.0))),
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
        content: const Center(
            child: Text('Copied to clipboard',
                style: TextStyle(color: Colors.white))),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(horizontalMargin, 0, horizontalMargin, 96),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16.0))),
        backgroundColor: const Color(0xFF00C853),
        duration: const Duration(milliseconds: 1500),
      ));
    } catch (_) {
      if (!mounted) return;
      final horizontalMargin = MediaQuery.of(context).size.width * 0.12;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Center(
            child: Text('Error copying to clipboard',
                style: TextStyle(color: Colors.white))),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(horizontalMargin, 0, horizontalMargin, 96),
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16.0))),
        backgroundColor: const Color(0xFFFF0000),
        duration: const Duration(milliseconds: 1500),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AccountTileUtils.getServiceColor(widget.item.service);

    // Debug flag: computed at runtime so analyzer doesn't treat branches as dead code.
    // Set this expression to `false` or change the condition to disable debug borders quickly.
    //final bool showDebugBorders = false; //MediaQuery.of(context).size.width > 0;

    // Helper to wrap a widget with a visible border when debugging is enabled
    Widget borderWrap(Widget child, {EdgeInsets? margin, EdgeInsets? padding}) {
      // if (!showDebugBorders) {
        return child;
      // } else {
      //   return Container(
      //     margin: margin,
      //     padding: padding,
      //     decoration: BoxDecoration(
      //       border: Border.all(color: Colors.redAccent, width: 1.0),
      //     ),
      //     child: child,
      //   );
      // }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final tile = borderWrap(
          SizedBox(
            height: 70,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                              // Top row: Avatar + Service name + OTP code
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar (ancho fijo) — add left padding
                    borderWrap(
                      Padding(
                        padding: const EdgeInsets.only(left: 12.0),
                        child: AccountTileUi.buildServiceAvatar(widget.item, color),
                      ),
                      padding: const EdgeInsets.all(2),
                    ),
                    const SizedBox(width: 8),
                    
                    // Service name (flexible width, allow ellipsis)
                    Expanded(
                      child: borderWrap(
                        Text(
                          widget.item.service,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w400),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        padding: const EdgeInsets.all(2),
                      ),
                    ),

                    // OTP code (takes needed space, no clipping, right aligned)
                    borderWrap(
                      Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: IntrinsicWidth(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: settings != null
                                ? AnimatedBuilder(
                                    animation: settings!,
                                    builder: (context, _) {
                                      return Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          borderRadius: BorderRadius.zero,
                                          onTap: () => _copyToClipboard(_otpService.currentCode),
                                          onLongPress: () {
                                            if (settings?.hideOtps == true) {
                                              setState(() { _revealCurrent = true; });
                                              _revealTimerCurrent?.cancel();
                                              _revealTimerCurrent = Timer(const Duration(seconds: 10), () {
                                                if (mounted) setState(() { _revealCurrent = false; });
                                              });
                                            }
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 2.0),
                                            child: Text(
                                              AccountTileUtils.formatCode(
                                                  _otpService.currentCode, settings, forceVisible: _revealCurrent),
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.visible,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : InkWell(
                                    onTap: () =>
                                        _copyToClipboard(_otpService.currentCode),
                                    child: Text(
                                      AccountTileUtils.formatCode(
                                          _otpService.currentCode, null),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.visible,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.all(2),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Bottom row: Account user + Next OTP + Progress dots
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Account username (flexible width, allow ellipsis, left aligned)
                    Expanded(
                      child: borderWrap(
                        Padding(
                          // add left padding so username is not flush with the tile edge
                          padding: const EdgeInsets.only(left: 12.0),
                          child: Text(
                            widget.item.account,
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey.shade600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        padding: const EdgeInsets.all(2),
                      ),
                    ),

                    // Next OTP (takes needed space, no clipping, right aligned)
                    borderWrap(
                      IntrinsicWidth(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: AnimatedBuilder(
                            animation: _animations.animController ??
                                Listenable.merge([]),
                            builder: (context, _) {
                              final anim = _animations.animController;
                              final opacity = (anim != null)
                                  ? anim.value.clamp(0.0, 1.0)
                                  : 1.0;
                              return Opacity(
                                opacity: opacity,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.zero,
                                    onTap: () => _copyToClipboard(_otpService.nextCode),
                                    onLongPress: () {
                                      if (settings?.hideOtps == true) {
                                        setState(() { _revealNext = true; });
                                        _revealTimerNext?.cancel();
                                        _revealTimerNext = Timer(const Duration(seconds: 10), () {
                                          if (mounted) setState(() { _revealNext = false; });
                                        });
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 2.0),
                                      child: Text(
                                        AccountTileUtils.formatCode(
                                            _otpService.nextCode, settings, forceVisible: _revealNext),
                                        style: TextStyle(fontSize: 14, color: Colors.black),
                                        maxLines: 1,
                                        overflow: TextOverflow.visible,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.all(2),
                    ),

                    const SizedBox(width: 12),

                    // Progress dots (fixed width, right aligned) — add right padding
                    borderWrap(
                      Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: AccountTileUi.buildProgressDots(
                            _animations.animController),
                      ),
                      padding: const EdgeInsets.all(2),
                    ),
                  ],
                ),
              ],
            ),
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
