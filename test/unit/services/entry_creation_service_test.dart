import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/models/account_entry.dart';
import 'package:pocket2fa/models/group_entry.dart';
import 'package:pocket2fa/services/api_service.dart';
import 'package:pocket2fa/services/entry_creation_service.dart';

import '../../helpers/fixtures/api_test_harness.dart';
import '../../helpers/fixtures/server_connection_fixture.dart';
import '../../helpers/reset.dart';

AccountEntry _entry({
  int id = -1,
  String service = 'Bank',
  String account = 'user@example.test',
  String seed = 'JBSWY3DPEHPK3PXP',
  String group = '',
  int? groupId,
  String? otpType = 'totp',
  int? digits = 6,
  String? algorithm = 'sha1',
  int? period = 30,
  int? counter,
}) {
  return AccountEntry(
    id: id,
    service: service,
    account: account,
    seed: seed,
    group: group,
    groupId: groupId,
    otpType: otpType,
    digits: digits,
    algorithm: algorithm,
    period: period,
    counter: counter,
    synchronized: false,
  );
}

void main() {
  final api = ApiService.instance;

  setUp(() {
    api.close();
    resetLogService();
  });
  tearDown(() {
    api.close();
    resetLogService();
  });

  ApiTestHarness configure() {
    api.setServer(serverConnectionFixture(), enableLogging: false);
    return ApiTestHarness(api.dio);
  }

  group('parseOtpAuthUrl', () {
    test('parses a TOTP URL with issuer and explicit parameters', () async {
      final entry = await EntryCreationService.parseOtpAuthUrl(
        'otpauth://totp/GitHub:alice@example.test'
        '?secret=JBSWY3DPEHPK3PXP'
        '&issuer=GitHub'
        '&algorithm=sha256'
        '&digits=8'
        '&period=60',
        null,
      );

      expect(entry, isNotNull);
      expect(entry!.id, -1);
      expect(entry.service, 'GitHub');
      expect(entry.account, 'GitHub_alice@example.test');
      expect(entry.seed, 'JBSWY3DPEHPK3PXP');
      expect(entry.group, isEmpty);
      expect(entry.groupId, isNull);
      expect(entry.otpType, 'TOTP');
      expect(entry.icon, isNull);
      expect(entry.localIcon, isNull);
      expect(entry.digits, 8);
      expect(entry.algorithm, 'SHA256');
      expect(entry.period, 60);
      expect(entry.counter, isNull);
      expect(entry.synchronized, isFalse);
    });

    test('splits a label with a colon when no issuer is present', () async {
      final entry = await EntryCreationService.parseOtpAuthUrl(
        'otpauth://totp/GitHub:alice?secret=JBSWY3DPEHPK3PXP',
        null,
      );

      expect(entry!.service, 'GitHub');
      expect(entry.account, 'alice');
    });

    test('keeps the full label as account when it has no colon', () async {
      final entry = await EntryCreationService.parseOtpAuthUrl(
        'otpauth://totp/alice@example.test?secret=JBSWY3DPEHPK3PXP',
        null,
      );

      expect(entry!.service, 'alice');
      expect(entry.account, 'alice@example.test');
    });

    test('uses the label query parameter when the path is empty', () async {
      final entry = await EntryCreationService.parseOtpAuthUrl(
        'otpauth://totp?secret=JBSWY3DPEHPK3PXP&label=Acme%3Abob',
        null,
      );

      expect(entry!.service, 'Acme');
      expect(entry.account, 'bob');
    });

    test(
      'uses the label query parameter when the path is only a slash',
      () async {
        final entry = await EntryCreationService.parseOtpAuthUrl(
          'otpauth://totp/?secret=JBSWY3DPEHPK3PXP&label=Acme%3Abob',
          null,
        );

        expect(entry!.service, 'Acme');
        expect(entry.account, 'bob');
      },
    );

    test('percent-decodes the label before splitting it', () async {
      final entry = await EntryCreationService.parseOtpAuthUrl(
        'otpauth://totp/My%20Service%3Aalice%40example.test'
        '?secret=JBSWY3DPEHPK3PXP',
        null,
      );

      expect(entry!.service, 'My Service');
      expect(entry.account, 'alice@example.test');
    });

    test('trims a lowercase secret without changing its case', () async {
      final entry = await EntryCreationService.parseOtpAuthUrl(
        'otpauth://totp/alice?secret=%20jbswy3dpehpk3pxp%20',
        null,
      );

      expect(entry!.seed, 'jbswy3dpehpk3pxp');
    });

    test('applies TOTP defaults for a minimal URL', () async {
      final entry = await EntryCreationService.parseOtpAuthUrl(
        'otpauth://totp/alice?secret=JBSWY3DPEHPK3PXP',
        null,
      );

      expect(entry!.service, 'alice');
      expect(entry.account, 'alice');
      expect(entry.otpType, 'TOTP');
      expect(entry.algorithm, 'SHA1');
      expect(entry.digits, 6);
      expect(entry.period, 30);
      expect(entry.counter, isNull);
    });

    test('falls back to defaults for invalid numeric parameters', () async {
      final entry = await EntryCreationService.parseOtpAuthUrl(
        'otpauth://totp/alice?secret=JBSWY3DPEHPK3PXP'
        '&digits=eight&period=soon&algorithm=sha512',
        null,
      );

      expect(entry!.digits, 6);
      expect(entry.period, 30);
      expect(entry.algorithm, 'SHA512');
    });

    test('parses a HOTP URL and uses the counter', () async {
      final entry = await EntryCreationService.parseOtpAuthUrl(
        'otpauth://hotp/Acme:bob?secret=JBSWY3DPEHPK3PXP&counter=7',
        null,
      );

      expect(entry!.service, 'Acme');
      expect(entry.account, 'bob');
      expect(entry.otpType, 'HOTP');
      expect(entry.counter, 7);
      expect(entry.period, isNull);
    });

    test('defaults a missing or invalid HOTP counter to zero', () async {
      for (final query in ['', '&counter=not-a-number']) {
        final entry = await EntryCreationService.parseOtpAuthUrl(
          'otpauth://hotp/alice?secret=JBSWY3DPEHPK3PXP$query',
          null,
        );

        expect(entry!.counter, 0);
        expect(entry.period, isNull);
      }
    });

    test('uses Unknown when the label and path are empty', () async {
      final entry = await EntryCreationService.parseOtpAuthUrl(
        'otpauth://totp/?secret=JBSWY3DPEHPK3PXP',
        null,
      );

      expect(entry!.account, 'Unknown');
      expect(entry.service, 'Unknown');
    });

    test('rejects non-otpauth schemes and unsupported hosts', () async {
      for (final url in [
        'https://example.test/?secret=JBSWY3DPEHPK3PXP',
        'otpauth://other/alice?secret=JBSWY3DPEHPK3PXP',
        'not a url',
      ]) {
        expect(
          await EntryCreationService.parseOtpAuthUrl(url, null),
          isNull,
          reason: url,
        );
      }
    });

    test('rejects missing, empty and non-Base32 secrets', () async {
      for (final query in [
        '',
        '&secret=',
        '&secret=0189',
        '&secret=ABC1',
        '&secret=JBSW-Y3DP',
      ]) {
        expect(
          await EntryCreationService.parseOtpAuthUrl(
            'otpauth://totp/alice$query',
            null,
          ),
          isNull,
          reason: query,
        );
      }
    });
  });

  group('buildManualEntry', () {
    test('builds a TOTP entry and replaces colons in the account', () {
      final entry = EntryCreationService.buildManualEntry(
        service: 'Bank',
        account: 'work:alice',
        secret: 'JBSWY3DPEHPK3PXP',
        otpType: 'totp',
        digits: 8,
        algorithm: 'sha256',
        period: 45,
        group: 'Work',
        groupId: 4,
      );

      expect(entry.id, -1);
      expect(entry.service, 'Bank');
      expect(entry.account, 'work_alice');
      expect(entry.seed, 'JBSWY3DPEHPK3PXP');
      expect(entry.group, 'Work');
      expect(entry.groupId, 4);
      expect(entry.otpType, 'TOTP');
      expect(entry.digits, 8);
      expect(entry.algorithm, 'sha256');
      expect(entry.period, 45);
      expect(entry.counter, isNull);
      expect(entry.synchronized, isFalse);
    });

    test('clamps a non-positive TOTP period to 30', () {
      for (final period in [0, -5]) {
        final entry = EntryCreationService.buildManualEntry(
          service: 'Bank',
          account: 'alice',
          secret: 'JBSWY3DPEHPK3PXP',
          otpType: 'TOTP',
          digits: 6,
          algorithm: 'SHA1',
          period: period,
        );

        expect(entry.period, 30, reason: 'period=$period');
        expect(entry.counter, isNull);
      }
    });

    test('uses the period argument as the HOTP counter', () {
      final entry = EntryCreationService.buildManualEntry(
        service: 'Bank',
        account: 'alice',
        secret: 'JBSWY3DPEHPK3PXP',
        otpType: 'hOtP',
        digits: 6,
        algorithm: 'SHA1',
        period: 7,
      );

      expect(entry.otpType, 'HOTP');
      expect(entry.counter, 7);
      expect(entry.period, isNull);
    });

    test('clamps a negative HOTP counter to zero', () {
      for (final period in [0, -1]) {
        final entry = EntryCreationService.buildManualEntry(
          service: 'Bank',
          account: 'alice',
          secret: 'JBSWY3DPEHPK3PXP',
          otpType: 'HOTP',
          digits: 6,
          algorithm: 'SHA1',
          period: period,
        );

        expect(entry.counter, 0, reason: 'period=$period');
        expect(entry.period, isNull);
      }
    });

    test('defaults the group fields', () {
      final entry = EntryCreationService.buildManualEntry(
        service: 'Bank',
        account: 'alice',
        secret: 'JBSWY3DPEHPK3PXP',
        otpType: 'TOTP',
        digits: 6,
        algorithm: 'SHA1',
        period: 30,
      );

      expect(entry.group, isEmpty);
      expect(entry.groupId, isNull);
    });
  });

  group('isValidBase32', () {
    test('accepts uppercase and lowercase Base32', () {
      expect(EntryCreationService.isValidBase32('JBSWY3DPEHPK3PXP'), isTrue);
      expect(EntryCreationService.isValidBase32('jbswy3dpehpk3pxp'), isTrue);
    });

    test('ignores separators and padding', () {
      expect(
        EntryCreationService.isValidBase32('JBSW Y3DP-EHPK 3PXP=='),
        isTrue,
      );
    });

    test('rejects empty or all-invalid input', () {
      for (final secret in ['', '0189', '---', '   ']) {
        expect(
          EntryCreationService.isValidBase32(secret),
          isFalse,
          reason: secret,
        );
      }
    });
  });

  group('createEntryOnServer', () {
    test(
      'returns the local entry without a request when the host is empty',
      () async {
        final local = _entry();

        final result = await EntryCreationService.createEntryOnServer(
          local,
          serverHost: '',
        );

        expect(identical(result, local), isTrue);
        expect(api.isReady, isFalse);
      },
    );

    test('sends a full TOTP payload and merges the server response', () async {
      final harness = configure();
      harness.adapter.onPost(
        'twofaccounts',
        (server) => server.reply(201, {
          'id': 12,
          'service': 'ServerBank',
          'account': 'server@example.test',
          'group_id': 4,
          'group': '',
        }),
      );

      final result = await EntryCreationService.createEntryOnServer(
        _entry(
          groupId: 4,
          otpType: 'totp',
          digits: 8,
          algorithm: 'sha256',
          period: 60,
        ),
        serverHost: 'http://example.test',
      );

      expect(harness.lastRequest.data, {
        'service': 'Bank',
        'account': 'user@example.test',
        'secret': 'JBSWY3DPEHPK3PXP',
        'otp_type': 'totp',
        'digits': 8,
        'algorithm': 'sha256',
        'period': 60,
        'group_id': 4,
      });
      expect(harness.lastRequest.data, isNot(contains('counter')));

      expect(result, isNotNull);
      expect(result!.id, 12);
      expect(result.service, 'ServerBank');
      expect(result.account, 'server@example.test');
      expect(result.seed, 'JBSWY3DPEHPK3PXP');
      expect(result.groupId, 4);
      expect(result.otpType, 'totp');
      expect(result.digits, 8);
      expect(result.algorithm, 'sha256');
      expect(result.period, 60);
      expect(result.counter, isNull);
      expect(result.synchronized, isTrue);
    });

    test('omits optional fields and defaults the TOTP period', () async {
      final harness = configure();
      harness.adapter.onPost(
        'twofaccounts',
        (server) => server.reply(201, {'id': 5}),
      );

      final result = await EntryCreationService.createEntryOnServer(
        _entry(otpType: null, digits: null, algorithm: null, period: null),
        serverHost: 'http://example.test',
      );

      expect(harness.lastRequest.data, {
        'service': 'Bank',
        'account': 'user@example.test',
        'secret': 'JBSWY3DPEHPK3PXP',
        'otp_type': 'totp',
        'period': 30,
      });
      expect(result!.id, 5);
      expect(result.seed, 'JBSWY3DPEHPK3PXP');
      expect(result.synchronized, isTrue);
    });

    test('sends the HOTP counter when present', () async {
      final harness = configure();
      harness.adapter.onPost(
        'twofaccounts',
        (server) => server.reply(201, {'id': 6}),
      );

      await EntryCreationService.createEntryOnServer(
        _entry(otpType: 'hotp', counter: 7, period: 30),
        serverHost: 'http://example.test',
      );

      expect(harness.lastRequest.data, {
        'service': 'Bank',
        'account': 'user@example.test',
        'secret': 'JBSWY3DPEHPK3PXP',
        'otp_type': 'hotp',
        'digits': 6,
        'algorithm': 'sha1',
        'counter': 7,
      });
      expect(harness.lastRequest.data, isNot(contains('period')));
    });

    test('uses the period as the HOTP counter fallback', () async {
      final harness = configure();
      harness.adapter.onPost(
        'twofaccounts',
        (server) => server.reply(201, {'id': 7}),
      );

      await EntryCreationService.createEntryOnServer(
        _entry(otpType: 'hotp', counter: null, period: 45),
        serverHost: 'http://example.test',
      );

      expect(harness.lastRequest.data['counter'], 45);
      expect(harness.lastRequest.data, isNot(contains('period')));
    });

    test('defaults the HOTP counter to zero', () async {
      final harness = configure();
      harness.adapter.onPost(
        'twofaccounts',
        (server) => server.reply(201, {'id': 8}),
      );

      await EntryCreationService.createEntryOnServer(
        _entry(otpType: 'hotp', counter: null, period: null),
        serverHost: 'http://example.test',
      );

      expect(harness.lastRequest.data['counter'], 0);
    });

    test('resolves the group name from the supplied groups', () async {
      final harness = configure();
      harness.adapter.onPost(
        'twofaccounts',
        (server) => server.reply(201, {'id': 9, 'group_id': 4}),
      );

      final result = await EntryCreationService.createEntryOnServer(
        _entry(groupId: null),
        serverHost: 'http://example.test',
        groups: [GroupEntry(id: 4, name: 'Work', twofaccountsCount: 2)],
      );

      expect(result!.group, 'Work');
      expect(result.groupId, 4);
    });

    test('keeps an empty group when the id has no matching group', () async {
      final harness = configure();
      harness.adapter.onPost(
        'twofaccounts',
        (server) => server.reply(201, {'id': 10, 'group_id': 99}),
      );

      final result = await EntryCreationService.createEntryOnServer(
        _entry(groupId: null),
        serverHost: 'http://example.test',
        groups: [GroupEntry(id: 4, name: 'Work', twofaccountsCount: 2)],
      );

      expect(result!.group, isEmpty);
      expect(result.groupId, 99);
    });

    test('keeps an empty group when no groups are supplied', () async {
      final harness = configure();
      harness.adapter.onPost(
        'twofaccounts',
        (server) => server.reply(201, {'id': 11, 'group_id': 4}),
      );

      final result = await EntryCreationService.createEntryOnServer(
        _entry(groupId: null),
        serverHost: 'http://example.test',
      );

      expect(result!.group, isEmpty);
    });

    test('prefers a group name returned by the server', () async {
      final harness = configure();
      harness.adapter.onPost(
        'twofaccounts',
        (server) => server.reply(201, {
          'id': 12,
          'group_id': 4,
          'group': 'Server Group',
        }),
      );

      final result = await EntryCreationService.createEntryOnServer(
        _entry(groupId: null),
        serverHost: 'http://example.test',
        groups: [GroupEntry(id: 4, name: 'Work', twofaccountsCount: 2)],
      );

      expect(result!.group, 'Server Group');
    });

    test('returns the local entry when the request fails', () async {
      final harness = configure();
      harness.adapter.onPost(
        'twofaccounts',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: 'twofaccounts'),
            type: DioExceptionType.connectionError,
          ),
        ),
      );
      final local = _entry();

      final result = await EntryCreationService.createEntryOnServer(
        local,
        serverHost: 'http://example.test',
      );

      expect(identical(result, local), isTrue);
      expect(result!.id, -1);
      expect(result.synchronized, isFalse);
    });

    test('returns the local entry for an unexpected response status', () async {
      final harness = configure();
      api.dio.options.validateStatus = (_) => true;
      harness.adapter.onPost(
        'twofaccounts',
        (server) => server.reply(200, {'id': 1}),
      );
      final local = _entry();

      final result = await EntryCreationService.createEntryOnServer(
        local,
        serverHost: 'http://example.test',
      );

      expect(identical(result, local), isTrue);
    });
  });
}
