import 'package:flutter/material.dart';
import '../models/account_entry.dart';
import '../services/settings_service.dart';
import 'account_tile_hotp.dart';
import 'account_tile_totp.dart';

class AccountTile extends StatelessWidget {
  final AccountEntry item;
  final SettingsService? settings;

  const AccountTile({required this.item, this.settings, super.key});

  @override
  Widget build(BuildContext context) {
    final isHotp = (item.otpType ?? 'totp').toLowerCase() == 'hotp';
    
    if (isHotp) {
      return AccountTileHOTP(item: item, settings: settings);
    } else {
      return AccountTileTOTP(item: item, settings: settings);
    }
  }
}
