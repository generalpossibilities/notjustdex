import 'package:d_vault/d_vault.dart';
import 'package:test/test.dart';

void main() {
  group('Key Derivation', () {
    test('derives key from username without salt', () async {
      final key = await deriveVaultKey(username: 'alice');
      expect(key.encryptionKey.length, 32);
      expect(key.authHash, isNull);
    });

    test('derives key from username with salt', () async {
      final key = await deriveVaultKey(username: 'alice', saltPassword: 'secret');
      expect(key.encryptionKey.length, 32);
      expect(key.authHash!.length, 32);
    });

    test('same inputs produce same key', () async {
      final a = await deriveVaultKey(username: 'bob', saltPassword: 'p@ss');
      final b = await deriveVaultKey(username: 'bob', saltPassword: 'p@ss');
      expect(a.encryptionKey, b.encryptionKey);
    });
  });

  group('Vault Encryption', () {
    test('encrypt then decrypt yields original', () async {
      final key = await deriveVaultKey(username: 'testuser');
      final entries = [
        PlaintextEntry(
          id: '1',
          username: 'user@example.com',
          password: 'hunter2',
          category: 'password',
          createdAt: 1000,
          updatedAt: 1000,
        ),
      ];

      final encrypted = await encryptVault(entries, key.encryptionKey);
      final decrypted = await decryptVault(encrypted, key.encryptionKey);

      expect(decrypted, isNotNull);
      expect(decrypted!.length, 1);
      expect(decrypted[0].username, 'user@example.com');
      expect(decrypted[0].password, 'hunter2');
    });

    test('wrong key returns null', () async {
      final key = await deriveVaultKey(username: 'alice');
      final wrong = await deriveVaultKey(username: 'bob');
      final entries = [
        PlaintextEntry(
          id: '1',
          username: 'u',
          password: 'p',
          category: 'password',
          createdAt: 0,
          updatedAt: 0,
        ),
      ];

      final encrypted = await encryptVault(entries, key.encryptionKey);
      final decrypted = await decryptVault(encrypted, wrong.encryptionKey);

      expect(decrypted, isNull);
    });
  });

  group('Seed Phrase', () {
    test('generates valid seed phrase', () {
      final phrase = generateSeedPhrase();
      expect(validateSeedPhrase(phrase), isTrue);
    });

    test('seed phrase produces 64 bytes', () {
      final phrase = generateSeedPhrase();
      final seed = seedFromMnemonic(phrase);
      expect(seed.length, 64);
    });
  });

  group('DVaultService', () {
    test('newEntry creates entry with correct fields', () {
      final entry = DVaultService.newEntry(
        username: 'user',
        password: 'pass',
        category: 'seed_phrase',
        notes: 'my seed',
      );

      expect(entry.username, 'user');
      expect(entry.password, 'pass');
      expect(entry.category, 'seed_phrase');
      expect(entry.notes, 'my seed');
      expect(entry.id.length, 32); // 16 bytes = 32 hex chars
    });
  });
}
