import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/otp_service.dart';
import '../services/api_service.dart';
import '../models/account_entry.dart';
import '../services/settings_service.dart';

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
  String currentCode = '------';
  String nextCode = '------';
  Timer? _timer;
  // HOTP transient display state
  String? _hotpCode;
  int? _hotpCounter;
  Timer? _hotpTimer;
  // Animation controller for per-period animations (dots + nextCode fade)
  AnimationController? _animController;

  @override
  void initState() {
    super.initState();
    // Use a one-shot timer per-tile: schedule the next refresh when the current
    // code expires (based on AccountEntry.period) instead of firing every second.
    _timer = null;
    // initial compute (which will schedule the next run)
    _refreshCodes();
  }

  @override
  void didUpdateWidget(covariant AccountTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != widget.item) {
      // account changed: cancel pending timer and refresh immediately
      _timer?.cancel();
      _timer = null;
      _refreshCodes();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hotpTimer?.cancel();
    try {
      _animController?.dispose();
    } catch (_) {}
    super.dispose();
  }

  void _stopAnimation() {
    try {
      _animController?.stop();
    } catch (_) {}
    try {
      _animController?.dispose();
    } catch (_) {}
    _animController = null;
  }

  void _startAnimation(int periodSec) {
    // No animation for HOTP
    final isHotp = (widget.item.otpType ?? 'totp').toLowerCase() == 'hotp';
    if (isHotp) {
      _stopAnimation();
      return;
    }

    final periodMs = (periodSec > 0 ? periodSec : 30) * 1000;
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final remMs = nowMs % periodMs;
    var progress = remMs / periodMs;
    if (progress < 0) progress = 0;
    if (progress > 1) progress = 0;

    // Recreate controller to reflect potential period changes
    try {
      _animController?.dispose();
    } catch (_) {}
    _animController = AnimationController(
        vsync: this, duration: Duration(milliseconds: periodMs));
    // Set initial progress; we'll animate to the end and then start repeating
    _animController!.value = progress;

    // Capture controller locally. Animate to the end of this cycle, then
    // start repeating full cycles using repeat(period: ...).
    final ctrl = _animController!;
    final remaining = (periodMs - remMs).clamp(0, periodMs);
    if (remaining == 0) {
      try {
        ctrl.repeat(period: Duration(milliseconds: periodMs));
      } catch (_) {}
    } else {
      try {
        ctrl
            .animateTo(1.0, duration: Duration(milliseconds: remaining))
            .then((_) {
          // If the controller is still the active one, start repeating
          if (identical(ctrl, _animController)) {
            try {
              ctrl.repeat(period: Duration(milliseconds: periodMs));
            } catch (_) {}
          }
        });
      } catch (_) {
        // ignore
      }
    }
  }

  Future<void> _refreshCodes() async {
    // compute current and next codes, then schedule next refresh at the
    // period boundary using AccountEntry.period (seconds).
    final acct = widget.item;
    final type = (acct.otpType ?? 'totp').toLowerCase();

    // Cancel any pending timer so we only have one scheduled refresh at a time.
    _timer?.cancel();
    _timer = null;

    if (type == 'steamtotp') {
      // Generate Steam TOTP locally (no network). Use the same generateOtp
      // helper that handles 'steamtotp' via OtpService.
      final c = OtpService.generateOtp(acct,
          timeOffsetSeconds: 0, storage: settings?.storage);
      final period = acct.period ?? 30;
      final n = OtpService.generateOtp(acct,
          timeOffsetSeconds: period, storage: settings?.storage);
      if (mounted) {
        setState(() {
          currentCode = c;
          nextCode = n;
        });
      }
      // Schedule next refresh at epoch-aligned period boundary.
      try {
        final periodSec =
            (acct.period != null && acct.period! > 0) ? acct.period! : 30;
        final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
        final periodMs = periodSec * 1000;
        final remMs = nowMs % periodMs;
        final delayMs = periodMs - remMs;
        _timer = Timer(Duration(milliseconds: delayMs + 50), () {
          if (mounted) _refreshCodes();
        });
        // Start per-period animation aligned to epoch
        _startAnimation(periodSec);
      } catch (_) {
        _timer = Timer(const Duration(seconds: 1), () {
          if (mounted) _refreshCodes();
        });
      }
      return;
    }

    // current (non-STEAM)
    final c = OtpService.generateOtp(acct,
        timeOffsetSeconds: 0, storage: settings?.storage);
    // next period: use period or default 30
    final period = acct.period ?? 30;
    final n = OtpService.generateOtp(acct,
        timeOffsetSeconds: period, storage: settings?.storage);
    if (mounted) {
      setState(() {
        currentCode = c;
        nextCode = n;
      });
      // Start per-period animation aligned to epoch
      _startAnimation(period);
    }
    // Schedule next refresh at the period boundary. Use milliseconds to avoid
    // drift. Add a small epsilon to ensure the code has actually advanced.
    try {
      final periodSec =
          (acct.period != null && acct.period! > 0) ? acct.period! : 30;
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final periodMs = periodSec * 1000;
      final remMs = nowMs % periodMs;
      final delayMs = periodMs - remMs;
      _timer = Timer(Duration(milliseconds: delayMs + 50), () {
        if (mounted) _refreshCodes();
      });
      // Start per-period animation aligned to epoch
      _startAnimation(periodSec);
    } catch (_) {
      // If scheduling fails for any reason, fallback to a conservative 1s tick
      _timer = Timer(const Duration(seconds: 1), () {
        if (mounted) _refreshCodes();
      });
    }
  }

  // HOTP consume behavior removed while HOTP is disabled.

  Future<void> _requestHotp() async {
    final acct = widget.item;
    try {
      final resp = await ApiService.instance.fetchAccountOtp(acct.id);
      final pwd = resp['password']?.toString() ?? '';
      final counter = resp['counter'] is int
          ? resp['counter'] as int
          : (resp['counter'] != null
              ? int.tryParse(resp['counter'].toString())
              : null);
      if (mounted) {
        setState(() {
          _hotpCode = pwd;
          _hotpCounter = counter;
        });
      }
      _hotpTimer?.cancel();
      _hotpTimer = Timer(const Duration(seconds: 30), () {
        if (mounted) {
          setState(() {
            _hotpCode = null;
            _hotpCounter = null;
          });
        }
      });
    } catch (_) {
      // On error, show 'offline' in the HOTP display area (transient)
      if (mounted) {
        setState(() {
          _hotpCode = 'offline';
          _hotpCounter = null;
        });
      }
      // Clear the transient offline state after 30s like a successful HOTP
      _hotpTimer?.cancel();
      _hotpTimer = Timer(const Duration(seconds: 30), () {
        if (mounted) {
          setState(() {
            _hotpCode = null;
            _hotpCounter = null;
          });
        }
      });
    }
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

  String _formatCode(String code) {
    // If the tile shows an offline indicator, return it verbatim so it
    // doesn't get grouped/spaced like numeric OTPs (fixes "off lin e").
    if (code.toLowerCase() == 'offline') return code;

    final digits = code.replaceAll(RegExp(r'\s+'), '');
    // If formatting is disabled, always return compact digits
    if (settings != null && settings!.enabled == false) return digits;

    final fmt = settings?.format ?? CodeFormat.compact;
    switch (fmt) {
      case CodeFormat.spaced3:
        return _group(digits, [3, 3]);
      case CodeFormat.spaced2:
        return _group(digits, [2, 2, 2]);
      case CodeFormat.compact:
        return digits;
    }
  }

  String _group(String s, List<int> groups) {
    final parts = <String>[];
    var i = 0;
    for (final g in groups) {
      if (i + g > s.length) break;
      parts.add(s.substring(i, i + g));
      i += g;
    }
    if (i < s.length) parts.add(s.substring(i));
    return parts.join(' ');
  }

  // currentCode/nextCode are updated periodically in state

  @override
  Widget build(BuildContext context) {
    final color =
        Colors.primaries[widget.item.service.length % Colors.primaries.length];
    // debugBoxes removed; restoring production layout
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(1.0),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: () {
                              const double radius = 14.0;
                              Widget fallbackAvatar() => CircleAvatar(
                                    radius: radius,
                                    backgroundColor: color.shade100,
                                    child: Text(
                                      widget.item.service.characters.first,
                                      style: TextStyle(
                                        color: color.shade900,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );

                              if (widget.item.localIcon != null &&
                                  widget.item.localIcon!.isNotEmpty) {
                                final file = File(widget.item.localIcon!);
                                final isSvg = widget.item.localIcon!
                                    .toLowerCase()
                                    .endsWith('.svg');
                                try {
                                  if (isSvg) {
                                    return CircleAvatar(
                                      radius: radius,
                                      backgroundColor: Colors.transparent,
                                      child: SvgPicture.file(
                                        file,
                                        width: radius * 2,
                                        height: radius * 2,
                                        fit: BoxFit.contain,
                                        placeholderBuilder: (ctx) =>
                                            fallbackAvatar(),
                                      ),
                                    );
                                  } else {
                                    return CircleAvatar(
                                      radius: radius,
                                      backgroundImage: FileImage(file),
                                      backgroundColor: Colors.transparent,
                                      onBackgroundImageError: (_, __) {},
                                    );
                                  }
                                } catch (_) {
                                  return fallbackAvatar();
                                }
                              }
                              return fallbackAvatar();
                            }(),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.item.service,
                              style: const TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.w400),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Second row: Account
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 10.0), // Align with service text
                        child: Text(
                          widget.item.account,
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
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
                  if (_hotpCode == null) {
                    return Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: ElevatedButton(
                              onPressed: _requestHotp,
                              style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, 36)),
                              child: const Text('Generate'),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  // When a HOTP has been requested, display it using the same
                  // styling and positioning as the main OTP code for consistency.
                  return Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(minWidth: 100, maxWidth: 110),
                        child: Container(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Align(
                                alignment: Alignment.centerLeft,
                                child: settings != null
                                    ? AnimatedBuilder(
                                        animation: settings!,
                                        builder: (context, _) {
                                          return InkWell(
                                            onTap: () => _copyToClipboard(_hotpCode ?? ''),
                                            child: Text(
                                                _formatCode(_hotpCode ?? ''),
                                                style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.w700)),
                                          );
                                        },
                                      )
                                    : InkWell(
                                        onTap: () => _copyToClipboard(_hotpCode ?? ''),
                                        child: Text(_formatCode(_hotpCode ?? ''),
                                            style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w700)),
                                      ),
                              ),
                              const SizedBox(height: 8),
                              if (_hotpCounter != null)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Text('counter $_hotpCounter',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade500)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
                            animation: _animController ?? Listenable.merge([]),
                            builder: (context, _) {
                              final anim = _animController;
                              final opacity = (anim != null)
                                  ? anim.value.clamp(0.0, 1.0)
                                  : 1.0;
                              return Opacity(
                                  opacity: opacity,
                                  child: Text(_formatCode(nextCode),
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
                                              onTap: () => _copyToClipboard(currentCode),
                                              child: Text(
                                                  _formatCode(currentCode),
                                                  style: const TextStyle(
                                                      fontSize: 24,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                            );
                                          },
                                        )
                                      : InkWell(
                                          onTap: () => _copyToClipboard(currentCode),
                                          child: Text(_formatCode(currentCode),
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
                                children: () {
                                  // Static colored dots (no animation): all dots shown in final color
                                  const int dotsCount = 10;
                                  const double dotSize = 5.0;
                                  const double spacing = 4.0;
                                  // Explicit colors for stability at startup
                                  const greenColor = Color(0xFF00C853);
                                  const yellowColor = Color(0xFFFFC107);
                                  const redColor = Color(0xFFD32F2F);

                                  // Wrap dots in an AnimatedBuilder so they update when the controller ticks.
                                  return [
                                    AnimatedBuilder(
                                      animation: _animController ?? AlwaysStoppedAnimation<double>(0.0),
                                      builder: (context, _) {
                                        final progress = (_animController != null) ? _animController!.value.clamp(0.0, 1.0) : 0.0;
                                        const int dotsCountLocal = dotsCount;
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: List.generate(dotsCountLocal, (j) {
                                            // Determine base color
                                            final baseColor = j < 6 ? greenColor : (j < 9 ? yellowColor : redColor);
                                            // Sequential activation: compute how many full dots and partial
                                            final scaled = progress * dotsCountLocal;
                                            final fullActive = scaled.floor();
                                            final partial = (scaled - fullActive).clamp(0.0, 1.0);
                                            Color dotColor;
                                            if (j < fullActive) {
                                              dotColor = baseColor;
                                            } else if (j == fullActive) {
                                              dotColor = Color.lerp(const Color(0xFFBDBDBD), baseColor, partial) ?? baseColor;
                                            } else {
                                              dotColor = const Color(0xFFBDBDBD);
                                            }

                                            return Padding(
                                              padding: EdgeInsets.only(left: j == 0 ? 0 : spacing),
                                              child: Container(
                                                width: dotSize,
                                                height: dotSize,
                                                decoration: BoxDecoration(
                                                  color: dotColor,
                                                  borderRadius: BorderRadius.circular(dotSize / 2.0),
                                                ),
                                              ),
                                            );
                                          }),
                                        );
                                      },
                                    ),
                                  ];
                                }(),
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
