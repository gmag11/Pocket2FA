import 'two_factor_item.dart';

class ServerConnection {
  final String id;
  final String name;
  final String url;
  final String apiKey;
  final List<TwoFactorItem> accounts;

  // User info fetched from /api/v1/user after validating the server
  final int? userId;
  final String? userName;
  final String? userEmail;
  final String? oauthProvider;
  final bool? authenticatedByProxy;
  final Map<String, dynamic>? preferences;
  final bool? isAdmin;

  ServerConnection({
    required this.id,
    required this.name,
    required this.url,
    required this.apiKey,
    required this.accounts,
    this.userId,
    this.userName,
    this.userEmail,
    this.oauthProvider,
    this.authenticatedByProxy,
    this.preferences,
    this.isAdmin,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'url': url,
        'apiKey': apiKey,
        'accounts': accounts.map((a) => a.toMap()).toList(),
        if (userId != null) 'user_id': userId,
        if (userName != null) 'user_name': userName,
        if (userEmail != null) 'user_email': userEmail,
        if (oauthProvider != null) 'oauth_provider': oauthProvider,
        if (authenticatedByProxy != null) 'authenticated_by_proxy': authenticatedByProxy,
        if (preferences != null) 'preferences': preferences,
        if (isAdmin != null) 'is_admin': isAdmin,
      };

  factory ServerConnection.fromMap(Map<dynamic, dynamic> m) => ServerConnection(
        id: m['id'] as String,
        name: m['name'] as String,
        url: m['url'] as String,
        apiKey: m['apiKey'] as String,
        accounts: (m['accounts'] as List<dynamic>).map((e) => TwoFactorItem.fromMap(Map<String, String>.from(e))).toList(),
        userId: m.containsKey('user_id') ? (m['user_id'] is int ? m['user_id'] as int : int.tryParse(m['user_id'].toString())) : null,
        userName: m['user_name'] as String?,
        userEmail: m['user_email'] as String?,
        oauthProvider: m['oauth_provider'] as String?,
        authenticatedByProxy: m.containsKey('authenticated_by_proxy') ? m['authenticated_by_proxy'] as bool? : null,
        preferences: m.containsKey('preferences') ? Map<String, dynamic>.from(m['preferences'] as Map) : null,
        isAdmin: m.containsKey('is_admin') ? m['is_admin'] as bool? : null,
      );
}
