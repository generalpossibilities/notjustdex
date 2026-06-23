import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:notjustdex_identity_kernel/identity_kernel.dart';

class MockIdentityRepository extends Mock implements IdentityRepository {}

class MockAnIdentityContract extends Mock implements AnIdentityContract {}

void main() {
  late MockIdentityRepository repository;
  late MockAnIdentityContract contract;
  late IdentityService service;

  setUp(() {
    repository = MockIdentityRepository();
    contract = MockAnIdentityContract();
    service = IdentityService(contract: contract, cache: repository);
  });

  group('IdentityService', () {
    test('throws when identity not found on chain and cache', () async {
      when(contract.getIdentity('nonexistent')).thenAnswer((_) async => null);
      when(repository.getIdentity('nonexistent')).thenAnswer((_) async => null);

      expect(
        () => service.getIdentity('nonexistent'),
        throwsA(isA<IdentityException>()),
      );
    });

    test('returns identity from chain when found', () async {
      final identity = UserIdentity(
        id: '0x123',
        username: Username('test'),
        profile: Profile(displayName: 'Test', username: 'test'),
        wallet: Wallet(address: '0x123', username: 'test'),
        authMethods: [],
        createdAt: DateTime.now(),
      );
      when(contract.getIdentity('0x123')).thenAnswer((_) async => identity);
      when(repository.saveIdentity(identity)).thenAnswer((_) async {});

      final result = await service.getIdentity('0x123');
      expect(result.id, '0x123');
    });

    test('falls back to cache on chain-down', () async {
      final identity = UserIdentity(
        id: '0x456',
        username: Username('cached'),
        profile: Profile(displayName: 'Cached', username: 'cached'),
        wallet: Wallet(address: '0x456', username: 'cached'),
        authMethods: [],
        createdAt: DateTime.now(),
      );
      when(contract.getIdentity('0x456')).thenThrow(Exception('chain-down'));
      when(repository.getIdentity('0x456')).thenAnswer((_) async => identity);

      final result = await service.getIdentity('0x456');
      expect(result.id, '0x456');
    });

    test('checkUsernameAvailability handles chain-down', () async {
      when(contract.isUsernameAvailable('test')).thenAnswer((_) async => null);

      final result = await service.checkUsernameAvailability('test');
      expect(result, false);
    });
  });
}
