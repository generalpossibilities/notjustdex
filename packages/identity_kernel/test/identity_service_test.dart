import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:notjustdex_identity_kernel/identity_kernel.dart';

class MockIdentityRepository extends Mock implements IdentityRepository {}

void main() {
  late MockIdentityRepository repository;
  late IdentityService service;

  setUp(() {
    repository = MockIdentityRepository();
    service = IdentityService(repository);
  });

  group('IdentityService', () {
    test('rejects invalid username on creation', () async {
      expect(
        () => service.createIdentity(
          phoneNumber: '+1234567890',
          username: 'ab',
          displayName: 'Test',
        ),
        throwsA(isA<IdentityException>()),
      );
    });

    test('rejects taken username on creation', () async {
      when(repository.checkUsernameAvailability('taken_user'))
          .thenAnswer((_) async => false);

      expect(
        () => service.createIdentity(
          phoneNumber: '+1234567890',
          username: 'taken_user',
          displayName: 'Test',
        ),
        throwsA(isA<IdentityException>()),
      );
    });

    test('throws when identity not found', () async {
      when(repository.getIdentity('nonexistent'))
          .thenAnswer((_) async => null);

      expect(
        () => service.getIdentity('nonexistent'),
        throwsA(isA<IdentityException>()),
      );
    });
  });
}
