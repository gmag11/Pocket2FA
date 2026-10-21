import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/services/api_service.dart';
import 'package:pocket2fa/services/log_service.dart';

import '../../helpers/fixtures/api_test_harness.dart';
import '../../helpers/fixtures/server_connection_fixture.dart';
import '../../helpers/reset.dart';

/// Log capture is the only API behavior that needs a Flutter binding, and the
/// binding replaces the real HTTP client. Keep this test in its own file so the
/// `validateServer` loopback tests in `api_service_test.dart` can use sockets.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final api = ApiService.instance;

  setUp(() {
    api.close();
    resetLogService();
  });

  tearDown(() {
    api.close();
    resetLogService();
  });

  test('masks secrets and identifiers in request and response logs', () async {
    api.setServer(
      serverConnectionFixture(apiKey: 'TOP-SECRET-KEY'),
      enableLogging: true,
    );
    LogService.instance.enabled = true;

    final harness = ApiTestHarness(api.dio);
    harness.adapter.onPost(
      'twofaccounts',
      (server) => server.reply(201, {
        'id': 1,
        'service': 'RESPONSE-SERVICE',
        'account': 'response@example.test',
        'secret': 'RESPONSE-SECRET',
        'note': 'visible',
      }),
    );

    await api.createAccount({
      'service': 'REQUEST-SERVICE',
      'account': 'request@example.test',
      'secret': 'REQUEST-SECRET',
      'apiKey': 'TOP-SECRET-KEY',
      'nested': {'seed': 'NESTED-SEED', 'note': 'visible'},
    });

    final logs = LogService.instance.entries
        .map((entry) => entry.message)
        .join('\n');

    for (final secret in [
      'REQUEST-SECRET',
      'RESPONSE-SECRET',
      'TOP-SECRET-KEY',
      'NESTED-SEED',
      'REQUEST-SERVICE',
      'RESPONSE-SERVICE',
      'request@example.test',
      'response@example.test',
    ]) {
      expect(logs, isNot(contains(secret)), reason: 'leaked $secret');
    }

    expect(logs, contains('***REDACTED***'));
    expect(logs, contains('***MASKED***'));
    expect(logs, contains('visible'));
  });
}
