// ignore_for_file: unused_import

// Imports every non-generated library under lib/ so `flutter test --coverage`
// instruments modules that no behavioral test loads. Without this, untouched
// files disappear from lcov.info and inflate the reported percentage.

import 'package:flutter_test/flutter_test.dart';

import 'package:pocket2fa/main.dart' as app;
import 'package:pocket2fa/models/account_entry.dart';
import 'package:pocket2fa/models/group_entry.dart';
import 'package:pocket2fa/models/server_connection.dart';
import 'package:pocket2fa/models/two_factor_item.dart';
import 'package:pocket2fa/models/user_preferences.dart';
import 'package:pocket2fa/screens/account_list.dart';
import 'package:pocket2fa/screens/accounts_screen.dart';
import 'package:pocket2fa/screens/advanced_form_screen.dart';
import 'package:pocket2fa/screens/bottom_bar.dart';
import 'package:pocket2fa/screens/home_header_animation.dart';
import 'package:pocket2fa/screens/home_manage_mode.dart';
import 'package:pocket2fa/screens/home_screen.dart';
import 'package:pocket2fa/screens/home_server_manager.dart';
import 'package:pocket2fa/screens/home_sync_manager.dart';
import 'package:pocket2fa/screens/image_qr_scanner_screen.dart';
import 'package:pocket2fa/screens/log_screen.dart';
import 'package:pocket2fa/screens/new_code_screen.dart';
import 'package:pocket2fa/screens/pin_lock_screen.dart';
import 'package:pocket2fa/screens/pin_settings_dialogs.dart';
import 'package:pocket2fa/screens/qr_scanner_screen.dart';
import 'package:pocket2fa/screens/search_bar.dart';
import 'package:pocket2fa/screens/server_add_edit_dialog.dart';
import 'package:pocket2fa/screens/server_detail_screen.dart';
import 'package:pocket2fa/screens/settings_screen.dart';
import 'package:pocket2fa/services/api_service.dart';
import 'package:pocket2fa/services/entry_creation_service.dart';
import 'package:pocket2fa/services/icon_cache_service.dart';
import 'package:pocket2fa/services/incoming_image_processor.dart';
import 'package:pocket2fa/services/log_service.dart';
import 'package:pocket2fa/services/otp_service.dart';
import 'package:pocket2fa/services/qr_image_scanner.dart';
import 'package:pocket2fa/services/settings_service.dart';
import 'package:pocket2fa/services/settings_storage.dart';
import 'package:pocket2fa/services/sync_service.dart';
import 'package:pocket2fa/services/window_geometry_service.dart';
import 'package:pocket2fa/widgets/about_dialog.dart';
import 'package:pocket2fa/widgets/account_tile.dart';
import 'package:pocket2fa/widgets/account_tile_animations.dart';
import 'package:pocket2fa/widgets/account_tile_hotp.dart';
import 'package:pocket2fa/widgets/account_tile_otp_service.dart';
import 'package:pocket2fa/widgets/account_tile_totp.dart';
import 'package:pocket2fa/widgets/account_tile_ui.dart';
import 'package:pocket2fa/widgets/account_tile_utils.dart';

void main() {
  test('every lib library is importable', () {
    expect(app.main, isNotNull);
  });
}
