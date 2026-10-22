import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/models/account_entry.dart';
import 'package:pocket2fa/models/server_connection.dart';
import 'package:pocket2fa/services/api_service.dart';

import '../../helpers/fixtures/api_test_harness.dart';
import '../../helpers/fixtures/server_connection_fixture.dart';
import '../../helpers/reset.dart';

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

  ApiTestHarness configure({
    ServerConnection? server,
    bool enableLogging = false,
  }) {
    api.setServer(
      server ?? serverConnectionFixture(),
      enableLogging: enableLogging,
    );
    return ApiTestHarness(api.dio);
  }

  group('server lifecycle', () {
    test('isReady flips after the first setServer and after close', () {
      expect(api.isReady, isFalse);

      configure();

      expect(api.isReady, isTrue);

      api.close();

      expect(api.isReady, isFalse);
    });

    test('re-selecting the same server keeps the existing Dio instance', () {
      final server = serverConnectionFixture();
      api.setServer(server, enableLogging: false);
      final first = api.dio;
      final interceptors = api.interceptors.length;

      api.setServer(server, enableLogging: false);

      expect(identical(api.dio, first), isTrue);
      expect(api.interceptors.length, interceptors);
    });

    test('switching servers creates a new Dio instance and base URL', () {
      api.setServer(serverConnectionFixture(id: 'one'), enableLogging: false);
      final first = api.dio;

      api.setServer(
        serverConnectionFixture(id: 'two', url: 'http://other.test'),
        enableLogging: false,
      );

      expect(identical(first, api.dio), isFalse);
      expect(api.dio.options.baseUrl, 'http://other.test/api/v1/');
    });

    test('trims every trailing slash from the server URL', () {
      configure(server: serverConnectionFixture(url: 'http://example.test///'));

      expect(api.dio.options.baseUrl, 'http://example.test/api/v1/');
    });

    test('sends the API key as a bearer token', () {
      configure(server: serverConnectionFixture(apiKey: 'secret-key'));

      expect(api.dio.options.headers['Authorization'], 'Bearer secret-key');
    });

    test('omits the Authorization header when the API key is empty', () {
      configure(server: serverConnectionFixture(apiKey: ''));

      expect(api.dio.options.headers.containsKey('Authorization'), isFalse);
    });

    test('configures the self-signed adapter when requested', () {
      api.setServer(
        serverConnectionFixture(allowSelfSigned: true),
        enableLogging: false,
      );

      expect(api.dio.httpClientAdapter, isA<IOHttpClientAdapter>());
    });

    test('close clears both the Dio instance and the guards', () {
      configure();
      final initial = api.interceptors.length;

      api.addInterceptor(InterceptorsWrapper());
      expect(api.interceptors.length, initial + 1);

      api.close();

      expect(() => api.dio, throwsStateError);
      expect(() => api.interceptors, throwsStateError);
      expect(() => api.addInterceptor(InterceptorsWrapper()), throwsStateError);
    });
  });

  group('fetchAccountOtp', () {
    test('parses every documented field and coerces numeric strings', () async {
      final harness = configure();
      harness.adapter.onGet(
        'twofaccounts/7/otp',
        (server) => server.reply(200, {
          'password': '123456',
          'next_password': '654321',
          'counter': '4',
          'otp_type': 'hotp',
          'period': '30',
          'generated_at': 1700000000,
        }),
      );

      final result = await api.fetchAccountOtp(7);

      expect(result, {
        'password': '123456',
        'next_password': '654321',
        'counter': 4,
        'otp_type': 'hotp',
        'period': 30,
        'generated_at': 1700000000,
      });
      expect(harness.lastRequest.path, 'twofaccounts/7/otp');
    });

    test('accepts the camelCase nextPassword variant', () async {
      final harness = configure();
      harness.adapter.onGet(
        'twofaccounts/1/otp',
        (server) =>
            server.reply(200, {'password': '111111', 'nextPassword': '222222'}),
      );

      final result = await api.fetchAccountOtp(1);

      expect(result['password'], '111111');
      expect(result['next_password'], '222222');
      expect(result['counter'], isNull);
      expect(result['period'], isNull);
      expect(result['generated_at'], isNull);
    });

    test('rejects a response without a password', () async {
      final harness = configure();
      harness.adapter.onGet(
        'twofaccounts/1/otp',
        (server) => server.reply(200, {'next_password': '222222'}),
      );

      await expectLater(api.fetchAccountOtp(1), throwsStateError);
    });

    test('rejects a non-map response body', () async {
      final harness = configure();
      harness.adapter.onGet(
        'twofaccounts/1/otp',
        (server) => server.reply(200, ['not', 'a', 'map']),
      );

      await expectLater(api.fetchAccountOtp(1), throwsStateError);
    });

    test('rejects an unexpected status even when Dio accepts it', () async {
      final harness = configure();
      api.dio.options.validateStatus = (_) => true;
      harness.adapter.onGet(
        'twofaccounts/1/otp',
        (server) => server.reply(404, {'message': 'missing'}),
      );

      await expectLater(api.fetchAccountOtp(1), throwsStateError);
    });

    test('rejects ids that are not positive', () async {
      configure();

      await expectLater(api.fetchAccountOtp(0), throwsArgumentError);
      await expectLater(api.fetchAccountOtp(-3), throwsArgumentError);
    });
  });

  group('createAccount', () {
    test('returns the 201 response body and posts the payload', () async {
      final harness = configure();
      harness.adapter.onPost(
        'twofaccounts',
        (server) => server.reply(201, {'id': 9, 'service': 'Bank'}),
      );

      final result = await api.createAccount({
        'service': 'Bank',
        'account': 'user@example.test',
        'secret': 'SEED',
      });

      expect(result, {'id': 9, 'service': 'Bank'});
      expect(harness.lastRequest.path, 'twofaccounts');
      expect(harness.lastRequest.data, {
        'service': 'Bank',
        'account': 'user@example.test',
        'secret': 'SEED',
      });
    });

    test('rejects a non-201 response', () async {
      final harness = configure();
      api.dio.options.validateStatus = (_) => true;
      harness.adapter.onPost(
        'twofaccounts',
        (server) => server.reply(200, {'id': 9}),
      );

      await expectLater(
        api.createAccount({'account': 'user'}),
        throwsStateError,
      );
    });

    test('rejects null and non-map response bodies', () async {
      final harness = configure();
      harness.adapter.onPost(
        'twofaccounts',
        (server) => server.reply(201, null),
      );

      await expectLater(
        api.createAccount({'account': 'user'}),
        throwsStateError,
      );

      harness.adapter.onPost(
        'twofaccounts',
        (server) => server.reply(201, 'created'),
      );

      await expectLater(
        api.createAccount({'account': 'user'}),
        throwsStateError,
      );
    });

    test('rethrows transport errors', () async {
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

      await expectLater(
        api.createAccount({'account': 'user'}),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('createAccountFromEntry', () {
    AccountEntry entry({
      int id = 0,
      String service = 'Bank',
      String account = 'user@example.test',
      String seed = 'JBSWY3DPEHPK3PXP',
      String? otpType,
      int? digits,
      String? algorithm,
      int? period,
      int? counter,
    }) {
      return AccountEntry(
        id: id,
        service: service,
        account: account,
        seed: seed,
        group: '',
        otpType: otpType,
        digits: digits,
        algorithm: algorithm,
        period: period,
        counter: counter,
      );
    }

    test('builds a full TOTP payload with a group id', () async {
      final harness = configure();
      harness.adapter.onPost(
        'twofaccounts',
        (server) => server.reply(201, {'id': 12}),
      );

      final result = await api.createAccountFromEntry(
        entry(otpType: 'totp', digits: 8, algorithm: 'sha256', period: 60),
        groupId: 4,
      );

      expect(result, {'id': 12});
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
    });

    test('uses counter for HOTP and falls back to the period', () async {
      final harness = configure();
      harness.adapter.onPost(
        'twofaccounts',
        (server) => server.reply(201, {'id': 13}),
      );

      await api.createAccountFromEntry(entry(otpType: 'HOTP', period: 30));

      final body = harness.lastRequest.data as Map<String, dynamic>;
      expect(body['counter'], 30);
      expect(body.containsKey('period'), isFalse);
      expect(body.containsKey('group_id'), isFalse);
    });

    test('omits optional and empty fields for a minimal entry', () async {
      final harness = configure();
      harness.adapter.onPost(
        'twofaccounts',
        (server) => server.reply(201, {'id': 14}),
      );

      await api.createAccountFromEntry(
        entry(service: '', seed: 'SEED', otpType: null),
      );

      expect(harness.lastRequest.data, {
        'account': 'user@example.test',
        'secret': 'SEED',
        'otp_type': 'totp',
      });
    });

    test('propagates createAccount errors', () async {
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

      await expectLater(
        api.createAccountFromEntry(entry()),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('deleteAccounts', () {
    test('does nothing for an empty id list', () async {
      final harness = configure();

      await api.deleteAccounts([]);

      expect(harness.requests, isEmpty);
    });

    test('sends ids as a comma-separated query and accepts 204', () async {
      final harness = configure();
      harness.adapter.onDelete(
        'twofaccounts',
        (server) => server.reply(204, null),
      );

      await api.deleteAccounts([1, 2]);

      expect(harness.lastRequest.path, 'twofaccounts');
      expect(harness.lastRequest.queryParameters, {'ids': '1,2'});
    });

    test('rejects an unexpected status even when Dio accepts it', () async {
      final harness = configure();
      api.dio.options.validateStatus = (_) => true;
      harness.adapter.onDelete(
        'twofaccounts',
        (server) => server.reply(200, {'deleted': true}),
      );

      await expectLater(api.deleteAccounts([1]), throwsStateError);
    });

    test('rethrows transport errors', () async {
      final harness = configure();
      harness.adapter.onDelete(
        'twofaccounts',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: 'twofaccounts'),
            type: DioExceptionType.connectionError,
          ),
        ),
      );

      await expectLater(api.deleteAccounts([1]), throwsA(isA<DioException>()));
    });
  });

  group('updateAccountFromEntry', () {
    AccountEntry entry({
      int id = 5,
      String service = 'Bank',
      String account = 'user@example.test',
      String seed = 'JBSWY3DPEHPK3PXP',
      String? otpType,
      int? digits,
      String? algorithm,
      int? period,
      int? counter,
      int? groupId,
      String? icon,
    }) {
      return AccountEntry(
        id: id,
        service: service,
        account: account,
        seed: seed,
        group: '',
        otpType: otpType,
        digits: digits,
        algorithm: algorithm,
        period: period,
        counter: counter,
        groupId: groupId,
        icon: icon,
      );
    }

    test('fills TOTP defaults and returns the updated map', () async {
      final harness = configure();
      harness.adapter.onPut(
        'twofaccounts/5',
        (server) => server.reply(200, {'id': 5, 'service': 'Bank'}),
      );

      final result = await api.updateAccountFromEntry(entry());

      expect(result, {'id': 5, 'service': 'Bank'});
      expect(harness.lastRequest.path, 'twofaccounts/5');
      expect(harness.lastRequest.data, {
        'service': 'Bank',
        'account': 'user@example.test',
        'secret': 'JBSWY3DPEHPK3PXP',
        'otp_type': 'totp',
        'digits': 6,
        'algorithm': 'sha1',
        'period': 30,
        'icon': null,
      });
    });

    test('uses counter for HOTP and omits the period', () async {
      final harness = configure();
      harness.adapter.onPut(
        'twofaccounts/6',
        (server) => server.reply(200, {'id': 6}),
      );

      await api.updateAccountFromEntry(entry(id: 6, otpType: 'hotp'));

      final body = harness.lastRequest.data as Map<String, dynamic>;
      expect(body['counter'], 0);
      expect(body.containsKey('period'), isFalse);
    });

    test('includes the group id and icon when present', () async {
      final harness = configure();
      harness.adapter.onPut(
        'twofaccounts/7',
        (server) => server.reply(200, {'id': 7}),
      );

      await api.updateAccountFromEntry(
        entry(id: 7, groupId: 4, icon: 'bank.png'),
      );

      final body = harness.lastRequest.data as Map<String, dynamic>;
      expect(body['group_id'], 4);
      expect(body['icon'], 'bank.png');
    });

    test('rejects an entry without a server id', () async {
      configure();

      await expectLater(
        api.updateAccountFromEntry(entry(id: 0)),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('valid server ID'),
          ),
        ),
      );
    });

    test('rejects non-map and non-200 responses', () async {
      final harness = configure();
      api.dio.options.validateStatus = (_) => true;

      harness.adapter.onPut(
        'twofaccounts/8',
        (server) => server.reply(200, 'ok'),
      );
      await expectLater(
        api.updateAccountFromEntry(entry(id: 8)),
        throwsA(isA<Exception>()),
      );

      harness.adapter.onPut(
        'twofaccounts/9',
        (server) => server.reply(500, {'message': 'boom'}),
      );
      await expectLater(
        api.updateAccountFromEntry(entry(id: 9)),
        throwsA(isA<Exception>()),
      );
    });

    test('rethrows transport errors', () async {
      final harness = configure();
      harness.adapter.onPut(
        'twofaccounts/10',
        (server) => server.throws(
          0,
          DioException(
            requestOptions: RequestOptions(path: 'twofaccounts/10'),
            type: DioExceptionType.connectionError,
          ),
        ),
      );

      await expectLater(
        api.updateAccountFromEntry(entry(id: 10)),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('downloadIcon', () {
    test('returns raw bytes and URL-encodes the file name', () async {
      final harness = configure();
      harness.adapter.onGet(
        RegExp(r'/storage/icons/'),
        (server) => server.reply(
          200,
          Uint8List.fromList([1, 2, 3, 255]),
          headers: {
            Headers.contentTypeHeader: ['application/octet-stream'],
          },
        ),
      );

      final bytes = await api.downloadIcon('my icon.png');

      expect(bytes, [1, 2, 3, 255]);
      expect(
        harness.lastRequest.path,
        endsWith('/storage/icons/my%20icon.png'),
      );
    });

    test('rejects an unexpected status even when Dio accepts it', () async {
      final harness = configure();
      api.dio.options.validateStatus = (_) => true;
      harness.adapter.onGet(
        RegExp(r'/storage/icons/'),
        (server) => server.reply(404, {'message': 'missing'}),
      );

      await expectLater(api.downloadIcon('missing.png'), throwsStateError);
    });
  });

  group('validateServer', () {
    Future<HttpServer> serve(
      Future<void> Function(HttpRequest request) handler,
    ) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen(handler);
      return server;
    }

    test('returns the user map from GET /api/v1/user', () async {
      final paths = <String>[];
      final server = await serve((request) async {
        paths.add(request.uri.path);
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"id":7,"name":"Alice"}');
        await request.response.close();
      });

      final result = await api.validateServer(
        serverConnectionFixture(url: 'http://127.0.0.1:${server.port}/'),
      );

      expect(result, {'id': 7, 'name': 'Alice'});
      expect(paths, ['/api/v1/user']);
    });

    test('throws a DioException for a non-200 response', () async {
      final server = await serve((request) async {
        request.response.statusCode = 500;
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"message":"boom"}');
        await request.response.close();
      });

      await expectLater(
        api.validateServer(
          serverConnectionFixture(url: 'http://127.0.0.1:${server.port}'),
        ),
        throwsA(isA<DioException>()),
      );
    });

    test('throws StateError for a non-map response', () async {
      final server = await serve((request) async {
        request.response.headers.contentType = ContentType.json;
        request.response.write('[]');
        await request.response.close();
      });

      await expectLater(
        api.validateServer(
          serverConnectionFixture(url: 'http://127.0.0.1:${server.port}'),
        ),
        throwsStateError,
      );
    });
  });

  group('friendlyErrorMessageFromDio', () {
    DioException dioError({
      int? status,
      Object? data,
      DioExceptionType type = DioExceptionType.badResponse,
      Object? error,
      String? message,
    }) {
      final options = RequestOptions(path: '/test');
      return DioException(
        requestOptions: options,
        response: status == null
            ? null
            : Response(requestOptions: options, statusCode: status, data: data),
        type: type,
        error: error,
        message: message,
      );
    }

    test('maps 400 with map and string details', () {
      expect(
        api.friendlyErrorMessageFromDio(
          dioError(status: 400, data: {'message': 'bad input'}),
        ),
        'Bad request (400): bad input',
      );
      expect(
        api.friendlyErrorMessageFromDio(
          dioError(status: 400, data: 'bad input'),
        ),
        'Bad request (400): bad input',
      );
      expect(
        api.friendlyErrorMessageFromDio(dioError(status: 400)),
        'Bad request (400)',
      );
    });

    test('maps authentication, permission, route and method errors', () {
      expect(
        api.friendlyErrorMessageFromDio(dioError(status: 401)),
        'Unauthorized (401). Check the API key.',
      );
      expect(
        api.friendlyErrorMessageFromDio(dioError(status: 403)),
        "Forbidden (403). You don't have permission.",
      );
      expect(
        api.friendlyErrorMessageFromDio(dioError(status: 404)),
        'Not found (404). Verify the server URL.',
      );
      expect(
        api.friendlyErrorMessageFromDio(dioError(status: 405)),
        'Method not allowed (405). Check the API documentation.',
      );
    });

    test('maps server errors with and without detail', () {
      expect(
        api.friendlyErrorMessageFromDio(
          dioError(status: 500, data: {'message': 'boom'}),
        ),
        'Server error (500). Try again later: boom',
      );
      expect(
        api.friendlyErrorMessageFromDio(dioError(status: 503)),
        'Server error (503). Try again later',
      );
      expect(
        api.friendlyErrorMessageFromDio(dioError(status: 418)),
        'Server error (418)',
      );
    });

    test('maps timeouts, cancellation and bad responses', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        expect(
          api.friendlyErrorMessageFromDio(dioError(type: type)),
          'Connection timed out. Check your network and server URL.',
        );
      }

      expect(
        api.friendlyErrorMessageFromDio(
          dioError(type: DioExceptionType.cancel),
        ),
        'Request cancelled.',
      );

      expect(
        api.friendlyErrorMessageFromDio(
          dioError(type: DioExceptionType.badResponse),
        ),
        'Bad response from server.',
      );
    });

    test('maps socket errors and the generic fallback', () {
      expect(
        api.friendlyErrorMessageFromDio(
          dioError(
            type: DioExceptionType.unknown,
            error: SocketException('Failed host lookup: example.test'),
          ),
        ),
        'Unable to resolve host. Check the server address and your internet connection.',
      );

      expect(
        api.friendlyErrorMessageFromDio(
          dioError(
            type: DioExceptionType.unknown,
            error: SocketException('No address associated with hostname'),
          ),
        ),
        'Unable to resolve host. Check the server address and your internet connection.',
      );

      expect(
        api.friendlyErrorMessageFromDio(
          dioError(
            type: DioExceptionType.unknown,
            error: SocketException('Connection refused'),
          ),
        ),
        'Connection error: Connection refused',
      );

      expect(
        api.friendlyErrorMessageFromDio(
          dioError(type: DioExceptionType.unknown, message: 'boom'),
        ),
        'Connection error: boom',
      );

      expect(
        api.friendlyErrorMessageFromDio(
          dioError(type: DioExceptionType.unknown),
        ),
        startsWith('Connection error: '),
      );
    });
  });

  group('friendlyErrorMessage', () {
    test(
      'delegates Dio errors, unwraps StateError and stringifies the rest',
      () {
        final options = RequestOptions(path: '/test');
        final dioFailure = DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 404),
          type: DioExceptionType.badResponse,
        );

        expect(
          api.friendlyErrorMessage(dioFailure),
          'Not found (404). Verify the server URL.',
        );
        expect(api.friendlyErrorMessage(StateError('nope')), 'nope');
        expect(api.friendlyErrorMessage(Exception('boom')), 'Exception: boom');
      },
    );
  });
}
