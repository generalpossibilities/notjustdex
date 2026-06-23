import 'dart:async';
import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:notjustdex_identity_kernel/identity_kernel.dart';

class MockIdentityRepository extends Mock implements IdentityRepository {}

class MockAnIdentityContract extends Mock implements AnIdentityContract {
  @override
  Future<UserIdentity?> getIdentity(String address) =>
      super.noSuchMethod(
        Invocation.method(#getIdentity, [address]),
        returnValue: Future<UserIdentity?>.value(null),
      ) as Future<UserIdentity?>;

  @override
  Future<bool?> isUsernameAvailable(String username) =>
      super.noSuchMethod(
        Invocation.method(#isUsernameAvailable, [username]),
        returnValue: Future<bool?>.value(null),
      ) as Future<bool?>;
}

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
      when(contract.getIdentity('nonexistent')).thenAnswer(
        (_) => Future<UserIdentity?>.value(null),
      );
      when(repository.getIdentity('nonexistent')).thenAnswer(
        (_) => Future<UserIdentity?>.value(null),
      );

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
      when(contract.getIdentity('0x456')).thenAnswer(
        (_) => Future.error(Exception('chain-down')),
      );
      when(repository.getIdentity('0x456')).thenAnswer((_) async => identity);

      final result = await service.getIdentity('0x456');
      expect(result.id, '0x456');
    });

    test('checkUsernameAvailability handles chain-down', () async {
      when(contract.isUsernameAvailable('test')).thenAnswer(
        (_) => Future<bool?>.value(null),
      );

      final result = await service.checkUsernameAvailability('test');
      expect(result, false);
    });
  });
}
