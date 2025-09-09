import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../models/account_entry.dart';
import '../services/settings_service.dart';
import 'account_tile_otp_service.dart';
import 'account_tile_ui.dart';
import 'account_tile_utils.dart';

class AccountTileHOTP extends StatefulWidget {
  final AccountEntry item;
  final SettingsService? settings;
  final bool isManageMode;
  final bool isSelected;
  final VoidCallback? onToggleSelection;
  final VoidCallback? onEdit;

  const AccountTileHOTP({
    required this.item,
    this.settings,
    this.isManageMode = false,
    this.isSelected = false,
    this.onToggleSelection,
    this.onEdit,
    super.key,
  });

  @override
  State<AccountTileHOTP> createState() => _AccountTileHOTPState();
}

class _AccountTileHOTPState extends State<AccountTileHOTP> {
  SettingsService? get settings => widget.settings;
  late AccountTileOtpService _otpService;
  Timer? _revealTimer;
  bool _reveal = false;
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _otpService = AccountTileOtpService(
      account: widget.item,
      settings: settings,
      refreshUi: () {
        if (mounted) setState(() {});
      },
      // HOTP does not require animations
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
    _revealTimer?.cancel();
    _otpService.dispose();
    super.dispose();
  }

  void _copyToClipboard(String code) async {
    if (!mounted) return;
    final trimmed = code.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'offline') {
      final horizontalMargin = MediaQuery.of(context).size.width * 0.12;
      final noCodeMsg = l10n.noCodeToCopy;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Center(
            child:
                Text(noCodeMsg, style: const TextStyle(color: Colors.white))),
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
      final copiedMsg = l10n.copied;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Center(
            child:
                Text(copiedMsg, style: const TextStyle(color: Colors.white))),
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
      final errorCopyMsg =
          l10n.errorCopyingToClipboard;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Center(
            child: Text(errorCopyMsg,
                style: const TextStyle(color: Colors.white))),
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

    if (widget.isManageMode) {
      return _buildManageModeUI(context, color);
    }

    return _buildNormalModeUI(context, color);
  }

  Widget _buildManageModeUI(BuildContext context, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final tile = SizedBox(
          height: 70, // Mantener la misma altura que en modo normal
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Top row: checkbox + avatar + service name + edit button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Checkbox para selección
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Transform.scale(
                      scale: 0.8, // Hacer el checkbox más pequeño
                      child: Checkbox(
                        value: widget.isSelected,
                        onChanged: (_) => widget.onToggleSelection?.call(),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // Avatar
                  AccountTileUi.buildServiceAvatar(widget.item, color),
                  const SizedBox(width: 8),

                  // Service name - expandible
                  Expanded(
                    child: Text(
                      widget.item.service,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w400),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Edit button
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: IconButton(
                      icon:
                          const Icon(Icons.edit, color: Colors.blue, size: 18),
                      onPressed: widget.onEdit,
                      padding: const EdgeInsets.all(4),
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ),
                ],
              ),

              // Small spacer (reduced in manage mode)
              //const SizedBox(height: 2),

              // Bottom row: account username aligned under service (use left padding to align with avatar in manage mode)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(
                          left: 56.0), // align under service like TOTP
                      child: Text(
                        widget.item.account,
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
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

  Widget _buildNormalModeUI(BuildContext context, Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final tile = SizedBox(
          height: 70,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left column: Avatar + Service name + Account user
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // First row: Avatar and service name
                      Row(
                        children: [
                          const SizedBox(width: 10),
                          AccountTileUi.buildServiceAvatar(widget.item, color),
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
                      // Second row: Account username
                      Padding(
                        padding: const EdgeInsets.only(left: 12.0),
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

              // Right column: HOTP states (takes minimal space)
              (() {
                if (_otpService.hotpCode == null) {
                  // State 1: "Generate" button centered vertically
                  return Container(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: ElevatedButton(
                          onPressed: _otpService.requestHotp,
                          style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 36)),
                          child: Text(l10n.generate),
                        ),
                      ),
                    ),
                  );
                }

                // State 2: OTP + Counter
                return Container(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // OTP right-aligned, no clipping
                      Align(
                        alignment: Alignment.centerRight,
                        child: settings != null
                            ? AnimatedBuilder(
                                animation: settings!,
                                builder: (context, _) {
                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.zero,
                                      onTap: () => _copyToClipboard(
                                          _otpService.hotpCode ?? ''),
                                      onLongPress: () {
                                        if (settings?.hideOtps == true) {
                                          setState(() {
                                            _reveal = true;
                                          });
                                          _revealTimer?.cancel();
                                          _revealTimer = Timer(
                                              const Duration(seconds: 10), () {
                                            if (mounted) {
                                              setState(() {
                                                _reveal = false;
                                              });
                                            }
                                          });
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 0.0, horizontal: 2.0),
                                        child: Text(
                                          AccountTileUtils.formatCode(
                                              _otpService.hotpCode ?? '',
                                              settings,
                                              forceVisible: _reveal),
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
                                onTap: () => _copyToClipboard(
                                    _otpService.hotpCode ?? ''),
                                child: Text(
                                  AccountTileUtils.formatCode(
                                      _otpService.hotpCode ?? '', null),
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                      ),
                      const SizedBox(height: 4),
                      // Counter centered horizontally
                      if (_otpService.hotpCounter != null)
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            l10n
                                .hotpCounter(_otpService.hotpCounter ?? 0),
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey.shade500),
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                    ],
                  ),
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
