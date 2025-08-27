import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import '../models/account_entry.dart';
import '../services/settings_service.dart';

class AccountTile extends StatelessWidget {
  final AccountEntry item;
  final SettingsService? settings;

  const AccountTile({required this.item, this.settings, super.key});

  String _formatCode(String code) {
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

  // Temporary OTP generator stub: real generation will use the account seed
  // and proper TOTP/HOTP algorithms. For now return the fixed placeholder.
  String _currentOtp() {
    return '000000';
  }

  String _nextOtp() {
    return '000000';
  }

  @override
  Widget build(BuildContext context) {
    final color = Colors.primaries[item.service.length % Colors.primaries.length];
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
              padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
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
                              item.service.characters.first,
                              style: TextStyle(
                                color: color.shade900,
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
                        }(),
                      ),
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
                  ),
                  const SizedBox(height: 4),
                  // Second row: Account
                  Padding(
                    padding: const EdgeInsets.only(left: 10.0), // Align with service text
                    child: Text(
                      item.account,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

      // Small code column (left of main code) - bottom-right aligned
          SizedBox(
            width: 54,
            height: 60,
              child: Align(
                alignment: Alignment.bottomRight,
                child: settings != null
                    ? AnimatedBuilder(
                        animation: settings!,
                        builder: (context, _) {
                              return Text(_formatCode(_nextOtp()), style: TextStyle(fontSize: 12, color: Colors.grey.shade500));
                            },
                      )
                    : Text(_formatCode(_nextOtp()), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ),
          ),

          const SizedBox(width: 8),

          // Main code column (right)
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 100, maxWidth: 110),
            child: Container(
              padding: const EdgeInsets.only(right: 8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: settings != null
                        ? AnimatedBuilder(
                            animation: settings!,
                            builder: (context, _) {
                              return Text(_formatCode(_currentOtp()), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700));
                            },
                          )
                        : Text(_formatCode(_currentOtp()), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(10, (i) {
                        final Color dotColor = i < 6
                            ? Colors.green.shade400
                            : (i < 9 ? Colors.amber.shade600 : Colors.red.shade400);
                        return Padding(
                          padding: EdgeInsets.only(left: i == 0 ? 0 : 6.0),
                          child: Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: dotColor,
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
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
}
