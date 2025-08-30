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
              // Columna izquierda: Avatar + Nombre servicio + Usuario
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Primera fila: Avatar y Nombre del servicio
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
                      // Segunda fila: Usuario de la cuenta
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

              // Columna derecha: Estados HOTP (ocupa espacio mínimo)
              (() {
                if (_otpService.hotpCode == null) {
                  // Estado 1: Botón "Generate" centrado verticalmente
                  return Container(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: ElevatedButton(
                          onPressed: _otpService.requestHotp,
                          style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 36)),
                          child: const Text('Generate'),
                        ),
                      ),
                    ),
                  );
                }

                // Estado 2: OTP + Contador
                return Container(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // OTP alineado a la derecha, sin recorte
                      Align(
                        alignment: Alignment.centerRight,
                        child: settings != null
                            ? AnimatedBuilder(
                                animation: settings!,
                                builder: (context, _) {
                                  return InkWell(
                                    onTap: () => _copyToClipboard(
                                        _otpService.hotpCode ?? ''),
                                    child: Text(
                                      AccountTileUtils.formatCode(
                                          _otpService.hotpCode ?? '',
                                          settings),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.visible,
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
                      // Contador centrado horizontalmente
                      if (_otpService.hotpCounter != null)
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            'counter ${_otpService.hotpCounter}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade500),
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