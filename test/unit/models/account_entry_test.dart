import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/models/account_entry.dart';

void main() {
  group('AccountEntry defaults', () {
    test('a minimal entry is synchronized, not deleted and not borrowed', () {
      final entry = AccountEntry(
        id: 1,
        service: 'Example',
        account: 'user',
        seed: 'JBSWY3DPEHPK3PXP',
        group: '',
      );

      expect(entry.synchronized, isTrue);
      expect(entry.deleted, isFalse);
      expect(entry.isBorrowed, isFalse);
      expect(entry.sharedBy, isNull);
      expect(entry.digits, isNull);
      expect(entry.period, isNull);
    });
  });
}
