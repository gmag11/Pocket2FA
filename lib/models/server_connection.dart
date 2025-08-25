import 'two_factor_item.dart';

class ServerConnection {
  final String id;
  final String name;
  final String url;
  final String apiKey;
  final List<TwoFactorItem> accounts;

  ServerConnection({required this.id, required this.name, required this.url, required this.apiKey, required this.accounts});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'url': url,
        'apiKey': apiKey,
        'accounts': accounts.map((a) => a.toMap()).toList(),
      };

  factory ServerConnection.fromMap(Map<dynamic, dynamic> m) => ServerConnection(
        id: m['id'] as String,
        name: m['name'] as String,
        url: m['url'] as String,
        apiKey: m['apiKey'] as String,
        accounts: (m['accounts'] as List<dynamic>).map((e) => TwoFactorItem.fromMap(Map<String, String>.from(e))).toList(),
      );
}
