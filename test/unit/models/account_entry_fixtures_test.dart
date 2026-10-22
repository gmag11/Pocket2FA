import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/models/account_entry.dart';

Map<String, dynamic> _load(String name) {
  final file = File('test/fixtures/$name');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  group('AccountEntry from a borrowed-account payload', () {
    late AccountEntry entry;

    setUp(() {
      entry = AccountEntry.fromMap(_load('twofaccounts_borrowed.json'));
    });

    test('is marked as borrowed and keeps the sharer name', () {
      expect(entry.isBorrowed, isTrue);
      expect(entry.sharedBy, 'Jane');
    });

    test('has no local secret', () {
      expect(entry.seed, isEmpty);
    });

    test('keeps the OTP parameters returned by the server', () {
      expect(entry.otpType, 'totp');
      expect(entry.period, 30);
      expect(entry.digits, 6);
      expect(entry.algorithm, 'sha1');
      expect(entry.groupId, 3);
    });
  });

  group('AccountEntry from an owned-account payload', () {
    late AccountEntry entry;

    setUp(() {
      entry = AccountEntry.fromMap(_load('twofaccounts_owned.json'));
    });

    test('defaults to not borrowed and keeps the secret', () {
      expect(entry.isBorrowed, isFalse);
      expect(entry.sharedBy, isNull);
      expect(entry.seed, 'JBSWY3DPEHPK3PXP');
    });

    test('defaults to synchronized and not deleted', () {
      expect(entry.synchronized, isTrue);
      expect(entry.deleted, isFalse);
    });

    test('exposes the fields the UI reads', () {
      expect(entry.service, 'MySite');
      expect(entry.account, 'john.doe');
      expect(entry.group, 'Personal');
      expect(entry.groupId, 1);
    });
  });
}
