import 'package:pocket2fa/models/account_entry.dart';
import 'package:pocket2fa/models/server_connection.dart';

/// Builds a [ServerConnection] for API tests with deterministic defaults.
///
/// Each test passes only the fields it cares about, so the required
/// constructor arguments do not obscure the behavior under test.
ServerConnection serverConnectionFixture({
  String id = 'server-1',
  String name = 'Test Server',
  String url = 'http://example.test',
  String apiKey = 'test-api-key',
  List<AccountEntry> accounts = const [],
  String userEmail = 'user@example.test',
  bool allowSelfSigned = false,
}) {
  return ServerConnection(
    id: id,
    name: name,
    url: url,
    apiKey: apiKey,
    accounts: accounts,
    userEmail: userEmail,
    allowSelfSigned: allowSelfSigned,
  );
}
