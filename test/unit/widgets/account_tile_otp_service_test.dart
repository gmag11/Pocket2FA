import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/models/account_entry.dart';
import 'package:pocket2fa/services/api_service.dart';
import 'package:pocket2fa/services/otp_service.dart';
import 'package:pocket2fa/widgets/account_tile_otp_service.dart';

import '../../helpers/clock.dart';
import '../../helpers/fixtures/api_test_harness.dart';
import '../../helpers/fixtures/server_connection_fixture.dart';
import '../../helpers/reset.dart';

AccountEntry _account({
  int id = 1,
  String seed = 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ',
  String? otpType = 'totp',
  int? period = 30,
  int? digits = 8,
  bool isBorrowed = false,
}) {
  return AccountEntry(
    id: id,
    service: 'Test',
    account: 'alice',
    seed: seed,
    group: '',
    otpType: otpType,
    period: period,
    digits: digits,
    isBorrowed: isBorrowed,
  );
}

void main() {
  final api = ApiService.instance;
  final fixed = utcFromUnixSeconds(59);

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

  group('initial state and local generation', () {
    test('starts with placeholder codes and no HOTP value', () {
      final svc = AccountTileOtpService(
        account: _account(),
        settings: null,
        refreshUi: () {},
      );
      addTearDown(svc.dispose);

      expect(svc.currentCode, '------');
      expect(svc.nextCode, '------');
      expect(svc.hotpCode, isNull);
      expect(svc.hotpCounter, isNull);
    });

    test(
      'generates the current and next TOTP code at a fixed instant',
      () async {
        var refreshCalls = 0;
        var animationCalls = 0;

        await withFixedTimeAsync(fixed, () async {
          final account = _account();
          final svc = AccountTileOtpService(
            account: account,
            settings: null,
            refreshUi: () => refreshCalls++,
            startAnimationCallback: () => animationCalls++,
          );
          addTearDown(svc.dispose);

          await svc.refreshCodes();

          expect(svc.currentCode, '94287082');
          expect(
            svc.nextCode,
            OtpService.generateOtp(account, timeOffsetSeconds: 30),
          );
          expect(refreshCalls, 1);
          expect(animationCalls, 1);
        });
      },
    );

    test(
      'generates the current and next Steam code at a fixed instant',
      () async {
        var refreshCalls = 0;
        var animationCalls = 0;

        await withFixedTimeAsync(fixed, () async {
          final account = _account(otpType: 'steamtotp', digits: null);
          final svc = AccountTileOtpService(
            account: account,
            settings: null,
            refreshUi: () => refreshCalls++,
            startAnimationCallback: () => animationCalls++,
          );
          addTearDown(svc.dispose);

          await svc.refreshCodes();

          expect(svc.currentCode, OtpService.generateOtp(account));
          expect(svc.currentCode, hasLength(5));
          expect(
            svc.nextCode,
            OtpService.generateOtp(account, timeOffsetSeconds: 30),
          );
          expect(refreshCalls, 1);
          expect(animationCalls, 1);
        });
      },
    );
  });

  group('lifecycle and server routing', () {
    test('dispose cancels the scheduled local refresh', () {
      fakeAsync((async) {
        var refreshCalls = 0;
        var animationCalls = 0;
        final svc = AccountTileOtpService(
          account: _account(),
          settings: null,
          refreshUi: () => refreshCalls++,
          startAnimationCallback: () => animationCalls++,
        );

        unawaited(svc.refreshCodes());
        async.flushMicrotasks();

        expect(refreshCalls, 1);
        expect(animationCalls, 1);

        svc.dispose();
        async.elapse(const Duration(minutes: 2));
        async.flushMicrotasks();

        expect(refreshCalls, 1);
        expect(animationCalls, 1);
      });
    });

    test('a borrowed account without a server id goes offline and retries', () {
      fakeAsync((async) {
        final harness = configure();
        var refreshCalls = 0;
        final svc = AccountTileOtpService(
          account: _account(id: 0, seed: '', isBorrowed: true),
          settings: null,
          refreshUi: () => refreshCalls++,
        );

        unawaited(svc.refreshCodes());
        async.flushMicrotasks();

        expect(svc.currentCode, 'offline');
        expect(svc.nextCode, isEmpty);
        expect(refreshCalls, 1);
        expect(harness.requests, isEmpty);

        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();

        expect(svc.currentCode, 'offline');
        expect(refreshCalls, 2);
        expect(harness.requests, isEmpty);

        svc.dispose();
      });
    });

    test(
      'an empty seed with a server id goes offline when the API is missing',
      () async {
        var refreshCalls = 0;
        final svc = AccountTileOtpService(
          account: _account(id: 7, seed: ''),
          settings: null,
          refreshUi: () => refreshCalls++,
        );
        addTearDown(svc.dispose);

        await svc.refreshCodes();

        expect(svc.currentCode, 'offline');
        expect(svc.nextCode, isEmpty);
        expect(refreshCalls, 1);
      },
    );
  });

  group('server-backed refresh', () {
    AccountTileOtpService service({
      int id = 42,
      int? period = 30,
      required void Function() refreshUi,
      void Function()? startAnimation,
    }) {
      return AccountTileOtpService(
        account: _account(id: id, seed: '', period: period, isBorrowed: true),
        settings: null,
        refreshUi: refreshUi,
        startAnimationCallback: startAnimation,
      );
    }

    test('fetches the current and next code from the server', () async {
      final harness = configure();
      harness.adapter.onGet(
        'twofaccounts/42/otp',
        (server) => server.reply(200, {
          'password': '123456',
          'next_password': '654321',
          'period': 30,
          'generated_at': 1700000000,
        }),
      );
      var refreshCalls = 0;
      var animationCalls = 0;
      final svc = service(
        refreshUi: () => refreshCalls++,
        startAnimation: () => animationCalls++,
      );
      addTearDown(svc.dispose);

      await svc.refreshCodes();

      expect(svc.currentCode, '123456');
      expect(svc.nextCode, '654321');
      expect(refreshCalls, 1);
      expect(animationCalls, 1);
      expect(harness.lastRequest.path, 'twofaccounts/42/otp');
    });

    test('shows placeholders when the server omits the next code', () async {
      final harness = configure();
      harness.adapter.onGet(
        'twofaccounts/42/otp',
        (server) => server.reply(200, {
          'password': '123456',
          'period': 30,
          'generated_at': 1700000000,
        }),
      );
      final svc = service(refreshUi: () {});
      addTearDown(svc.dispose);

      await svc.refreshCodes();

      expect(svc.currentCode, '123456');
      expect(svc.nextCode, '------');
    });

    test('goes offline when the server returns an empty password', () async {
      final harness = configure();
      harness.adapter.onGet(
        'twofaccounts/42/otp',
        (server) => server.reply(200, {
          'password': '',
          'next_password': '654321',
          'period': 30,
        }),
      );
      var refreshCalls = 0;
      final svc = service(refreshUi: () => refreshCalls++);
      addTearDown(svc.dispose);

      await svc.refreshCodes();

      expect(svc.currentCode, 'offline');
      expect(svc.nextCode, isEmpty);
      expect(refreshCalls, 1);
    });

    test('goes offline when the request fails', () async {
      final harness = configure();
      harness.adapter.onGet(
        'twofaccounts/42/otp',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: 'twofaccounts/42/otp'),
            type: DioExceptionType.connectionError,
          ),
        ),
      );
      var refreshCalls = 0;
      final svc = service(refreshUi: () => refreshCalls++);
      addTearDown(svc.dispose);

      await svc.refreshCodes();

      expect(svc.currentCode, 'offline');
      expect(refreshCalls, 1);
    });

    test('uses the local period when the server omits it', () async {
      final harness = configure();
      harness.adapter.onGet(
        'twofaccounts/42/otp',
        (server) => server.reply(200, {
          'password': '111111',
          'next_password': '222222',
          'generated_at': 1700000000,
        }),
      );
      final svc = service(period: 45, refreshUi: () {});
      addTearDown(svc.dispose);

      await svc.refreshCodes();

      expect(svc.currentCode, '111111');
      expect(svc.nextCode, '222222');
    });

    test('defaults to 30 seconds when neither period is available', () async {
      final harness = configure();
      harness.adapter.onGet(
        'twofaccounts/42/otp',
        (server) => server.reply(200, {
          'password': '111111',
          'next_password': '222222',
          'generated_at': 1700000000,
        }),
      );
      final svc = service(period: null, refreshUi: () {});
      addTearDown(svc.dispose);

      await svc.refreshCodes();

      expect(svc.currentCode, '111111');
    });

    test('accepts generated_at in milliseconds', () async {
      final harness = configure();
      harness.adapter.onGet(
        'twofaccounts/42/otp',
        (server) => server.reply(200, {
          'password': '111111',
          'next_password': '222222',
          'period': 30,
          'generated_at': 1700000000000,
        }),
      );
      final svc = service(refreshUi: () {});
      addTearDown(svc.dispose);

      await svc.refreshCodes();

      expect(svc.currentCode, '111111');
      expect(svc.nextCode, '222222');
    });

    test('accepts generated_at as a numeric string', () async {
      final harness = configure();
      harness.adapter.onGet(
        'twofaccounts/42/otp',
        (server) => server.reply(200, {
          'password': '111111',
          'next_password': '222222',
          'period': 30,
          'generated_at': '1700000000',
        }),
      );
      final svc = service(refreshUi: () {});
      addTearDown(svc.dispose);

      await svc.refreshCodes();

      expect(svc.currentCode, '111111');
    });

    test(
      'falls back to the client clock when generated_at is missing',
      () async {
        final harness = configure();
        harness.adapter.onGet(
          'twofaccounts/42/otp',
          (server) => server.reply(200, {'password': '111111', 'period': 30}),
        );
        final svc = service(refreshUi: () {});
        addTearDown(svc.dispose);

        await svc.refreshCodes();

        expect(svc.currentCode, '111111');
        expect(svc.nextCode, '------');
      },
    );

    test('ignores a response that arrives after dispose', () async {
      final harness = configure();
      harness.adapter.onGet(
        'twofaccounts/42/otp',
        (server) => server.reply(200, {
          'password': '123456',
          'next_password': '654321',
          'period': 30,
        }),
      );
      var refreshCalls = 0;
      final svc = service(refreshUi: () => refreshCalls++);

      final future = svc.refreshCodes();
      svc.dispose();
      await future;

      expect(svc.currentCode, '------');
      expect(refreshCalls, 0);
    });

    test('schedules the next fetch at the generated_at boundary', () {
      fakeAsync((async) {
        final harness = configure();
        harness.adapter.onGet(
          'twofaccounts/42/otp',
          (server) => server.reply(200, {
            'password': '111111',
            'next_password': '222222',
            'period': 30,
            'generated_at': 1700000000,
          }),
        );
        var refreshCalls = 0;
        final svc = service(refreshUi: () => refreshCalls++);

        unawaited(svc.refreshCodes());
        async.elapse(Duration.zero);

        expect(svc.currentCode, '111111');
        expect(refreshCalls, 1);

        const periodMs = 30 * 1000;
        const generatedAtMs = 1700000000 * 1000;
        final delayMs = periodMs - (generatedAtMs % periodMs) + 250;

        async.elapse(Duration(milliseconds: delayMs - 1));
        async.flushMicrotasks();
        expect(refreshCalls, 1);

        async.elapse(const Duration(milliseconds: 2));
        async.flushMicrotasks();
        expect(refreshCalls, 2);

        svc.dispose();
      });
    });
  });

  group('HOTP requests', () {
    AccountTileOtpService hotpService({
      int id = 42,
      required void Function() refreshUi,
    }) {
      return AccountTileOtpService(
        account: _account(id: id, seed: '', otpType: 'hotp'),
        settings: null,
        refreshUi: refreshUi,
      );
    }

    test('stores an integer counter from the server', () async {
      final harness = configure();
      harness.adapter.onGet(
        'twofaccounts/42/otp',
        (server) => server.reply(200, {'password': '123456', 'counter': 4}),
      );
      var refreshCalls = 0;
      final svc = hotpService(refreshUi: () => refreshCalls++);
      addTearDown(svc.dispose);

      await svc.requestHotp();

      expect(svc.hotpCode, '123456');
      expect(svc.hotpCounter, 4);
      expect(refreshCalls, 1);
      expect(harness.lastRequest.path, 'twofaccounts/42/otp');
    });

    test('parses a string counter from the server', () async {
      final harness = configure();
      harness.adapter.onGet(
        'twofaccounts/42/otp',
        (server) => server.reply(200, {'password': '123456', 'counter': '9'}),
      );
      final svc = hotpService(refreshUi: () {});
      addTearDown(svc.dispose);

      await svc.requestHotp();

      expect(svc.hotpCode, '123456');
      expect(svc.hotpCounter, 9);
    });

    test('keeps a null counter when the server omits it', () async {
      final harness = configure();
      harness.adapter.onGet(
        'twofaccounts/42/otp',
        (server) => server.reply(200, {'password': '123456'}),
      );
      final svc = hotpService(refreshUi: () {});
      addTearDown(svc.dispose);

      await svc.requestHotp();

      expect(svc.hotpCode, '123456');
      expect(svc.hotpCounter, isNull);
    });

    test('shows offline on a request failure', () async {
      var refreshCalls = 0;
      final svc = hotpService(refreshUi: () => refreshCalls++);
      addTearDown(svc.dispose);

      await svc.requestHotp();

      expect(svc.hotpCode, 'offline');
      expect(svc.hotpCounter, isNull);
      expect(refreshCalls, 1);
    });

    test('clears a successful HOTP code after 30 seconds', () {
      fakeAsync((async) {
        final harness = configure();
        harness.adapter.onGet(
          'twofaccounts/42/otp',
          (server) => server.reply(200, {'password': '123456', 'counter': 4}),
        );
        var refreshCalls = 0;
        final svc = hotpService(refreshUi: () => refreshCalls++);

        unawaited(svc.requestHotp());
        async.elapse(Duration.zero);

        expect(svc.hotpCode, '123456');
        expect(svc.hotpCounter, 4);
        expect(refreshCalls, 1);

        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();

        expect(svc.hotpCode, isNull);
        expect(svc.hotpCounter, isNull);
        expect(refreshCalls, 2);

        svc.dispose();
      });
    });

    test('clears the offline HOTP state after 30 seconds', () {
      fakeAsync((async) {
        var refreshCalls = 0;
        final svc = hotpService(refreshUi: () => refreshCalls++);

        unawaited(svc.requestHotp());
        async.elapse(Duration.zero);

        expect(svc.hotpCode, 'offline');
        expect(refreshCalls, 1);

        async.elapse(const Duration(seconds: 30));
        async.flushMicrotasks();

        expect(svc.hotpCode, isNull);
        expect(svc.hotpCounter, isNull);
        expect(refreshCalls, 2);

        svc.dispose();
      });
    });
  });
}
