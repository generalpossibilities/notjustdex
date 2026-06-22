import 'package:test/test.dart';
import 'package:notjustdex_identity_kernel/src/models/username.dart';

void main() {
  group('Username', () {
    test('accepts valid usernames (min 4 chars)', () {
      expect(Username.tryCreate('john'), isNotNull);
      expect(Username.tryCreate('john_doe'), isNotNull);
      expect(Username.tryCreate('Alice123'), isNotNull);
      expect(Username.tryCreate('a_b_c_d_e'), isNotNull);
    });

    test('rejects usernames shorter than 4 chars', () {
      expect(Username.tryCreate('a'), isNull);
      expect(Username.tryCreate('ab'), isNull);
      expect(Username.tryCreate('abc'), isNull);
      expect(Username.tryCreate(''), isNull);
    });

    test('rejects invalid characters', () {
      expect(Username.tryCreate('a@user'), isNull);
      expect(Username.tryCreate('user name'), isNull);
    });

    test('rejects too long', () {
      expect(Username.tryCreate('a'.padRight(33, 'b')), isNull);
    });

    test('lowercases on creation', () {
      final username = Username('Alice');
      expect(username.value, 'alice');
    });

    test('rejects with throw for invalid', () {
      expect(() => Username(''), throwsArgumentError);
    });

    test('toString shows @ prefix', () {
      final username = Username('test_user');
      expect(username.toString(), '@test_user');
    });
  });
}
