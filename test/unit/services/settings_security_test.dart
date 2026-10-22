import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket2fa/services/settings_storage.dart';

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('isValidPin', () {
    test('accepts 4 to 8 digits', () {
      expect(isValidPin('1234'), isTrue);
      expect(isValidPin('12345678'), isTrue);
      expect(isValidPin('0000'), isTrue);
    });

    test('rejects shorter, longer and non-digit values', () {
      expect(isValidPin('123'), isFalse);
      expect(isValidPin('123456789'), isFalse);
      expect(isValidPin('12a4'), isFalse);
      expect(isValidPin('12 34'), isFalse);
      expect(isValidPin(''), isFalse);
    });
  });

  group('derivePinHash', () {
    // PBKDF2-HMAC-SHA256 vectors with P="password" and S="salt".
    const password = 'password';
    final salt = utf8.encode('salt');

    test('matches the published vector at one iteration', () {
      final hash = derivePinHash(pin: password, salt: salt, iterations: 1);

      expect(
        _hex(hash),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
    });

    test('matches the published vector at two iterations', () {
      final hash = derivePinHash(pin: password, salt: salt, iterations: 2);

      expect(
        _hex(hash),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
    });

    test('honours the requested key length', () {
      final full = derivePinHash(pin: password, salt: salt, iterations: 1);
      final short = derivePinHash(
        pin: password,
        salt: salt,
        iterations: 1,
        keyLength: 16,
      );

      expect(short, hasLength(16));
      expect(short, full.sublist(0, 16));
    });

    test('is deterministic and sensitive to the PIN and salt', () {
      final first = derivePinHash(pin: password, salt: salt, iterations: 2);
      final again = derivePinHash(pin: password, salt: salt, iterations: 2);
      final otherPin = derivePinHash(
        pin: 'Password',
        salt: salt,
        iterations: 2,
      );
      final otherSalt = derivePinHash(
        pin: password,
        salt: utf8.encode('pepper'),
        iterations: 2,
      );

      expect(again, first);
      expect(otherPin, isNot(first));
      expect(otherSalt, isNot(first));
    });
  });

  group('constantTimeEquals', () {
    test('accepts identical byte sequences', () {
      expect(constantTimeEquals([1, 2, 3], [1, 2, 3]), isTrue);
      expect(constantTimeEquals(const [], const []), isTrue);
    });

    test('rejects different values', () {
      expect(constantTimeEquals([1, 2, 3], [1, 2, 4]), isFalse);
    });

    test('rejects different lengths', () {
      expect(constantTimeEquals([1, 2], [1, 2, 3]), isFalse);
      expect(constantTimeEquals([1, 2, 3], [1, 2]), isFalse);
    });
  });
}
