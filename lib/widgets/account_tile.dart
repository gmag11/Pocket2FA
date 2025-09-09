import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/account_entry.dart';
import '../services/settings_service.dart';
import 'account_tile_hotp.dart';
import 'account_tile_totp.dart';

class AccountTile extends StatelessWidget {
  final AccountEntry item;
  final SettingsService? settings;
  final bool isManageMode;
  final bool isSelected;
  final VoidCallback? onToggleSelection;
  final VoidCallback? onEdit; // New callback for edit

  const AccountTile({
    super.key,
    required this.item,
    this.settings,
    this.isManageMode = false,
    this.isSelected = false,
    this.onToggleSelection,
    this.onEdit, // Add to constructor
  });

  @override
  Widget build(BuildContext context) {
    final isHotp = (item.otpType ?? 'totp').toLowerCase() == 'hotp';
    Widget child;
    if (isHotp) {
      child = AccountTileHOTP(
        key: key,
        item: item,
        settings: settings,
        isManageMode: isManageMode,
        isSelected: isSelected,
        onToggleSelection: onToggleSelection,
        onEdit: onEdit,
      );
    } else {
      child = AccountTileTOTP(
        key: key,
        item: item,
        settings: settings,
        isManageMode: isManageMode,
        isSelected: isSelected,
        onToggleSelection: onToggleSelection,
        onEdit: onEdit,
      );
    }

    // If the entry is not synchronized, overlay a small indicator badge.
    if (item.synchronized == false) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          // Larger, high-contrast badge placed inside the tile's top-right
          // Position the badge near the center-right so it doesn't obscure title or OTP digits.
          Positioned.fill(
            child: Align(
              // Move the badge to the center-bottom of the tile so it sits
              // visually centered and below the main content without
              // overlapping title/OTP digits.
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Tooltip(
                  message: AppLocalizations.of(context)!.pendingUpload,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.red.shade700,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2)),
                      ],
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Center(
                      child:
                          Icon(Icons.cloud_off, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return child;
  }
}
