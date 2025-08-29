import 'account_entry.dart';
import 'group_entry.dart';
import 'user_preferences.dart';

class ServerConnection {
  final String id;
  final String name;
  final String url;
  final String apiKey;
    final List<AccountEntry> accounts;

  // User info fetched from /api/v1/user after validating the server
  final int? userId;
  final String? userName;
  // Make userEmail non-nullable to ensure UI cannot accidentally show an
  // account name in place of the user's email. If unknown it will be an
  // empty string.
  final String userEmail;
  final String? oauthProvider;
  final bool? authenticatedByProxy;
  final UserPreferences? preferences;
  final bool? isAdmin;
  final List<GroupEntry>? groups;

  ServerConnection({
    required this.id,
    required this.name,
    required this.url,
    required this.apiKey,
    required this.accounts,
  this.userId,
  this.userName,
  required this.userEmail,
    this.oauthProvider,
    this.authenticatedByProxy,
  this.preferences,
    this.isAdmin,
    this.groups,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'url': url,
        'apiKey': apiKey,
    'accounts': accounts.map((a) => a.toMap()).toList(),
        if (groups != null) 'groups': groups!.map((g) => g.toMap()).toList(),
      if (userId != null) 'user_id': userId,
        if (userName != null) 'user_name': userName,
        // Always include user_email (may be empty string)
        'user_email': userEmail,
          if (oauthProvider != null) 'oauth_provider': oauthProvider,
          if (authenticatedByProxy != null)
            'authenticated_by_proxy': authenticatedByProxy,
          if (preferences != null) 'preferences': preferences!.toMap(),
        if (isAdmin != null) 'is_admin': isAdmin,
      };

  factory ServerConnection.fromMap(Map<dynamic, dynamic> m) => ServerConnection(
        id: m['id'] as String,
        name: m['name'] as String,
        url: m['url'] as String,
        apiKey: m['apiKey'] as String,
        accounts: (m['accounts'] as List<dynamic>)
            .map((e) => AccountEntry.fromMap(Map<dynamic, dynamic>.from(e)))
            .toList(),
        groups: m.containsKey('groups') && m['groups'] is List
            ? (m['groups'] as List<dynamic>)
                .map((e) => GroupEntry.fromMap(Map<dynamic, dynamic>.from(e)))
                .toList()
            : null,
    userId: m.containsKey('user_id')
      ? (m['user_id'] is int
        ? m['user_id'] as int
        : int.tryParse(m['user_id'].toString()))
      : null,
    userName: m['user_name'] as String?,
    // Ensure userEmail is non-nullable; default to empty string when absent
    userEmail: (m['user_email'] as String?) ?? '',
        oauthProvider: m['oauth_provider'] as String?,
    authenticatedByProxy: m.containsKey('authenticated_by_proxy')
      ? m['authenticated_by_proxy'] as bool?
      : null,
    preferences: m.containsKey('preferences')
      ? UserPreferences.fromMap(Map<dynamic, dynamic>.from(m['preferences'] as Map))
      : null,
        isAdmin: m.containsKey('is_admin') ? m['is_admin'] as bool? : null,
      );
}
