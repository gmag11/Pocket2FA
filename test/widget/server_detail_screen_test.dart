import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/models/account_entry.dart';
import 'package:pocket2fa/screens/server_detail_screen.dart';

import '../helpers/fixtures/server_connection_fixture.dart';
import '../helpers/pump.dart';

AccountEntry _account(int id, String service, String account) => AccountEntry(
  id: id,
  service: service,
  account: account,
  seed: 'JBSWY3DPEHPK3PXP',
  group: '',
);

void main() {
  testWidgets('renders the server title and every account row', (tester) async {
    final server = serverConnectionFixture(
      name: 'Work',
      accounts: [
        _account(1, 'GitHub', 'alice@example.test'),
        _account(2, 'GitLab', 'bob@example.test'),
      ],
    );

    await pumpApp(
      tester,
      ServerDetailScreen(server: server, onChanged: (_) {}),
    );

    expect(find.text('Server: Work'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('alice@example.test'), findsOneWidget);
    expect(find.text('GitLab'), findsOneWidget);
    expect(find.text('bob@example.test'), findsOneWidget);
  });
}
