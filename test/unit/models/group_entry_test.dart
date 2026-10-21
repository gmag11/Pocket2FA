import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/models/group_entry.dart';

void main() {
  group('GroupEntry', () {
    test('round-trips through toMap and fromMap', () {
      final group = GroupEntry(id: 7, name: 'Work', twofaccountsCount: 3);

      final restored = GroupEntry.fromMap(group.toMap());

      expect(restored.id, 7);
      expect(restored.name, 'Work');
      expect(restored.twofaccountsCount, 3);
      expect(restored.toMap(), group.toMap());
    });

    test('parses numeric strings from legacy payloads', () {
      final group = GroupEntry.fromMap({
        'id': '12',
        'name': 'Personal',
        'twofaccounts_count': '4',
      });

      expect(group.id, 12);
      expect(group.twofaccountsCount, 4);
    });

    test('falls back to zero for missing or unparseable values', () {
      final missing = GroupEntry.fromMap({});
      final invalid = GroupEntry.fromMap({
        'id': 'not-a-number',
        'name': null,
        'twofaccounts_count': 'many',
      });

      expect(missing.id, 0);
      expect(missing.name, '');
      expect(missing.twofaccountsCount, 0);

      expect(invalid.id, 0);
      expect(invalid.name, '');
      expect(invalid.twofaccountsCount, 0);
    });

    test('defaults the count when the key is present but null', () {
      final group = GroupEntry.fromMap({
        'id': 1,
        'name': 'Null count',
        'twofaccounts_count': null,
      });

      expect(group.twofaccountsCount, 0);
    });

    test('renders a readable toString', () {
      final group = GroupEntry(id: 2, name: 'Shared', twofaccountsCount: 9);

      expect(
        group.toString(),
        'GroupEntry(id: 2, name: Shared, twofaccountsCount: 9)',
      );
    });
  });
}
