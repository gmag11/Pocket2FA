import '../models/two_factor_item.dart';
import '../models/server_connection.dart';

final List<ServerConnection> sampleServers = [
  ServerConnection(
    id: 'srv-1',
  name: '2FAuth Domain1',
  url: 'https://2fauth.domain1.com',
    apiKey: 'apikey-123',
    accounts: [
      TwoFactorItem(service: 'Google', account: 'user@gmail.com', twoFa: '857740', nextTwoFa: '108089', group: 'Personal'),
      TwoFactorItem(service: 'GitHost', account: 'user@example.com', twoFa: '541678', nextTwoFa: '123456', group: 'Work'),
      TwoFactorItem(service: 'Facebook', account: 'user@facebook.com', twoFa: '123456', nextTwoFa: '654321', group: 'Personal'),
    ],
  ),
  ServerConnection(
    id: 'srv-2',
  name: '2FAuth Domain2',
  url: 'https://2fauth.domain2.com',
    apiKey: 'apikey-456',
    accounts: [
      TwoFactorItem(service: 'Dropbox', account: 'user@example.com', twoFa: '312450', nextTwoFa: '654321', group: 'Personal'),
      TwoFactorItem(service: 'AWS SSO', account: 'user@example.com', twoFa: '560595', nextTwoFa: '091891', group: 'Work'),
    ],
  ),
];

/// Flattened view for the existing UI (HomePage) which expects a list of TwoFactorItem
final List<TwoFactorItem> sampleItems = sampleServers.expand((s) => s.accounts).toList();
