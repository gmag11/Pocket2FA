import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';
import '../models/account_entry.dart';
import '../services/settings_service.dart';
import 'account_tile_utils.dart';

/// Reusable UI components for AccountTile
class AccountTileUi {
  /// Builds the service avatar
  static Widget buildServiceAvatar(AccountEntry item, Color color) {
    const double radius = 14.0;

    Widget fallbackAvatar() => CircleAvatar(
          radius: radius,
          backgroundColor: Color.fromRGBO(
            (color.r * 255.0).round() & 0xff,
            (color.g * 255.0).round() & 0xff,
            (color.b * 255.0).round() & 0xff, 0.2),
          child: Text(
            item.service.characters.first,
            style: TextStyle(
              color: Color.fromRGBO(
                (color.r * 255.0).round() & 0xff,
                (color.g * 255.0).round() & 0xff,
                (color.b * 255.0).round() & 0xff, 0.8),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        );

    if (item.localIcon != null && item.localIcon!.isNotEmpty) {
      final file = File(item.localIcon!);
      final isSvg = item.localIcon!.toLowerCase().endsWith('.svg');
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
              placeholderBuilder: (ctx) => fallbackAvatar(),
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
  }

  /// Builds the service info row
  static Widget buildServiceInfoRow(AccountEntry item, Color color) {
    return Row(
      children: [
        buildServiceAvatar(item, color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            item.service,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Builds the account info row
  static Widget buildAccountInfoRow(AccountEntry item) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: Text(
        item.account,
        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  /// Builds the HOTP generation button
  static Widget buildHotpButton(VoidCallback onPressed) {
    return Expanded(
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 36)),
              child: const Text('Generate'),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the HOTP display
  static Widget buildHotpDisplay({
    required String? hotpCode,
    required int? hotpCounter,
    required SettingsService? settings,
    required VoidCallback onCopy,
  }) {
    return Expanded(
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 100, maxWidth: 110),
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
                          animation: settings,
                          builder: (context, _) {
                            return InkWell(
                              onTap: onCopy,
                              child: Text(
                                AccountTileUtils.formatCode(hotpCode ?? '', settings),
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.w700),
                              ),
                            );
                          },
                        )
                      : InkWell(
                          onTap: onCopy,
                          child: Text(
                            AccountTileUtils.formatCode(hotpCode ?? '', null),
                            style: const TextStyle(
                                fontSize: 24, fontWeight: FontWeight.w700),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                if (hotpCounter != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text('counter $hotpCounter',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the time progress dots
  static Widget buildProgressDots(AnimationController? animController) {
    const int dotsCount = 10;
    const double dotSize = 5.0;
    const double spacing = 4.0;
    const greenColor = Color(0xFF00C853);
    const yellowColor = Color(0xFFFFC107);
    const redColor = Color(0xFFD32F2F);

    return AnimatedBuilder(
      animation: animController ?? AlwaysStoppedAnimation<double>(0.0),
      builder: (context, _) {
        final progress = (animController != null)
            ? animController.value.clamp(0.0, 1.0)
            : 0.0;
        const int dotsCountLocal = dotsCount;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(dotsCountLocal, (j) {
            final baseColor =
                j < 6 ? greenColor : (j < 9 ? yellowColor : redColor);
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
    );
  }
}