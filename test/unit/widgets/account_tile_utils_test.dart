import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/services/settings_service.dart';
import 'package:pocket2fa/widgets/account_tile_utils.dart';

import '../../helpers/fakes/fake_settings_storage.dart';

Future<SettingsService> _settings({
  CodeFormat format = CodeFormat.spaced3,
  bool enabled = true,
  bool hideOtps = false,
}) async {
  final service = SettingsService(storage: FakeSettingsStorage());
  await service.reloadFromStorage();
  await service.setFormat(format);
  await service.setEnabled(enabled);
  await service.setHideOtps(hideOtps);
  return service;
}

void main() {
  group('formatCode', () {
    test(
      'returns the code unchanged when it is the offline sentinel',
      () async {
        final settings = await _settings(format: CodeFormat.spaced3);

        expect(AccountTileUtils.formatCode('offline', settings), 'offline');
        expect(AccountTileUtils.formatCode('OFFLINE', settings), 'OFFLINE');
      },
    );

    test('uses compact formatting without settings', () {
      expect(AccountTileUtils.formatCode('123456', null), '123456');
      expect(AccountTileUtils.formatCode(' 12 34 56 ', null), '123456');
    });

    test('groups six digits for spaced3 and spaced2', () async {
      final spaced3 = await _settings(format: CodeFormat.spaced3);
      final spaced2 = await _settings(format: CodeFormat.spaced2);

      expect(AccountTileUtils.formatCode('123456', spaced3), '123 456');
      expect(AccountTileUtils.formatCode('123456', spaced2), '12 34 56');
    });

    test('keeps a short tail after complete groups', () async {
      final spaced3 = await _settings(format: CodeFormat.spaced3);
      final spaced2 = await _settings(format: CodeFormat.spaced2);

      expect(AccountTileUtils.formatCode('1234', spaced3), '123 4');
      expect(AccountTileUtils.formatCode('12345', spaced2), '12 34 5');
    });

    test('strips existing whitespace before grouping', () async {
      final settings = await _settings(format: CodeFormat.spaced3);

      expect(AccountTileUtils.formatCode(' 1 2 3 4 5 6 ', settings), '123 456');
    });

    test('disabled formatting always returns compact digits', () async {
      final settings = await _settings(
        format: CodeFormat.spaced2,
        enabled: false,
      );

      expect(AccountTileUtils.formatCode('12 34 56', settings), '123456');
    });

    test('disabled formatting does not apply the hidden mask', () async {
      final settings = await _settings(enabled: false, hideOtps: true);

      expect(AccountTileUtils.formatCode('123456', settings), '123456');
    });

    test('hides OTP digits while preserving grouping spaces', () async {
      final spaced3 = await _settings(
        format: CodeFormat.spaced3,
        hideOtps: true,
      );
      final spaced2 = await _settings(
        format: CodeFormat.spaced2,
        hideOtps: true,
      );

      expect(AccountTileUtils.formatCode('123456', spaced3), '••• •••');
      expect(AccountTileUtils.formatCode('123456', spaced2), '•• •• ••');
    });

    test('forced visibility bypasses the hidden mask', () async {
      final settings = await _settings(
        format: CodeFormat.spaced3,
        hideOtps: true,
      );

      expect(
        AccountTileUtils.formatCode('123456', settings, forceVisible: true),
        '123 456',
      );
    });

    test('hides a short code that fills complete groups', () async {
      final settings = await _settings(
        format: CodeFormat.spaced2,
        hideOtps: true,
      );

      expect(AccountTileUtils.formatCode('1234', settings), '•• ••');
    });
  });

  group('getServiceColor', () {
    test('returns a stable color for the same service', () {
      final first = AccountTileUtils.getServiceColor('GitHub');
      final second = AccountTileUtils.getServiceColor('GitHub');

      expect(first, second);
    });

    test('uses the documented character-sum primary index', () {
      final color = AccountTileUtils.getServiceColor('GitHub');
      final index =
          'GitHub'.codeUnits.fold(0, (sum, unit) => sum + unit) %
          Colors.primaries.length;

      expect(color, Colors.primaries[index]);
    });

    test('falls back to the account name when service is empty', () {
      final expected = AccountTileUtils.getServiceColor('alice');
      final actual = AccountTileUtils.getServiceColor('', 'alice');

      expect(actual, expected);
    });

    test('falls back to the first primary when both names are empty', () {
      expect(AccountTileUtils.getServiceColor(''), Colors.primaries[0]);
      expect(AccountTileUtils.getServiceColor('', ''), Colors.primaries[0]);
    });
  });
}
