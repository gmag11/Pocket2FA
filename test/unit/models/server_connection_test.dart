import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/models/account_entry.dart';
import 'package:pocket2fa/models/group_entry.dart';
import 'package:pocket2fa/models/server_connection.dart';
import 'package:pocket2fa/models/user_preferences.dart';

AccountEntry _account() {
  return AccountEntry(
    id: 1,
    service: 'GitHub',
    account: 'ana',
    seed: 'JBSWY3DPEHPK3PXP',
    group: 'Work',
    groupId: 7,
    otpType: 'totp',
    icon: 'github.png',
    digits: 6,
    algorithm: 'sha1',
    period: 30,
    counter: 2,
    localIcon: '/tmp/github.png',
    synchronized: true,
    deleted: false,
    isBorrowed: true,
    sharedBy: 'bob',
  );
}

ServerConnection _connection() {
  return ServerConnection(
    id: 'server-1',
    name: 'Home',
    url: 'https://2fa.example.com',
    apiKey: 'api-key',
    accounts: [_account()],
    userId: 42,
    userName: 'ana',
    userEmail: 'ana@example.com',
    oauthProvider: 'github',
    authenticatedByProxy: true,
    preferences: UserPreferences.fromMap({
      'theme': 'dark',
      'showNextOtp': true,
    }),
    isAdmin: true,
    groups: [GroupEntry(id: 7, name: 'Work', twofaccountsCount: 1)],
    allowSelfSigned: true,
  );
}

Map<String, dynamic> _minimalPayload() => {
  'id': 'server-2',
  'name': 'Minimal',
  'url': 'https://minimal.example.com',
  'apiKey': 'key',
  'accounts': <dynamic>[],
};

void main() {
  group('ServerConnection', () {
    test('round-trips nested accounts, groups and preferences', () {
      final connection = _connection();

      final restored = ServerConnection.fromMap(connection.toMap());

      expect(restored.id, 'server-1');
      expect(restored.name, 'Home');
      expect(restored.url, 'https://2fa.example.com');
      expect(restored.apiKey, 'api-key');
      expect(restored.userId, 42);
      expect(restored.userName, 'ana');
      expect(restored.userEmail, 'ana@example.com');
      expect(restored.oauthProvider, 'github');
      expect(restored.authenticatedByProxy, isTrue);
      expect(restored.isAdmin, isTrue);
      expect(restored.allowSelfSigned, isTrue);

      expect(
        restored.accounts.single.toMap(),
        connection.accounts.single.toMap(),
      );
      expect(
        restored.groups!.single.toMap(),
        connection.groups!.single.toMap(),
      );
      expect(restored.preferences!.toMap(), connection.preferences!.toMap());
      expect(restored.toMap(), connection.toMap());
    });

    test('omits unset optional fields from toMap', () {
      final connection = ServerConnection(
        id: 'server-3',
        name: 'Optional',
        url: 'https://optional.example.com',
        apiKey: 'key',
        accounts: const [],
        userEmail: '',
      );

      final map = connection.toMap();

      expect(
        map.keys,
        containsAll(['id', 'name', 'url', 'apiKey', 'accounts']),
      );
      expect(map, containsPair('user_email', ''));
      for (final key in [
        'user_id',
        'user_name',
        'oauth_provider',
        'authenticated_by_proxy',
        'preferences',
        'is_admin',
        'groups',
        'allow_self_signed',
      ]) {
        expect(map, isNot(contains(key)), reason: '$key should be omitted');
      }
    });

    test('applies defaults when optional fields are absent', () {
      final restored = ServerConnection.fromMap(_minimalPayload());

      expect(restored.userEmail, '');
      expect(restored.allowSelfSigned, isFalse);
      expect(restored.userId, isNull);
      expect(restored.userName, isNull);
      expect(restored.oauthProvider, isNull);
      expect(restored.authenticatedByProxy, isNull);
      expect(restored.isAdmin, isNull);
      expect(restored.preferences, isNull);
      expect(restored.groups, isNull);
    });

    test('parses a numeric user id and an empty group list', () {
      final restored = ServerConnection.fromMap({
        ..._minimalPayload(),
        'user_id': '42',
        'groups': <dynamic>[],
      });

      expect(restored.userId, 42);
      expect(restored.groups, isEmpty);
    });

    test('keeps an unparseable user id as null', () {
      final restored = ServerConnection.fromMap({
        ..._minimalPayload(),
        'user_id': 'not-a-number',
      });

      expect(restored.userId, isNull);
    });
  });
}
