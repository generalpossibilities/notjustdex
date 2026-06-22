import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

const String _domainSep = 'd-vault-v1';

class VaultKey {
  final List<int> encryptionKey;
  final List<int>? authHash;

  VaultKey({required this.encryptionKey, this.authHash});
}

Future<VaultKey> deriveVaultKey({
  required String username,
  String? saltPassword,
}) async {
  final baseInput = utf8.encode('$_domainSep$username');
  final baseHash = await Sha256().hash(baseInput);
  final baseKey = baseHash.bytes;

  if (saltPassword == null || saltPassword.isEmpty) {
    // SHA-256 gives 32 bytes — use as encryption key directly
    return VaultKey(encryptionKey: baseKey);
  }

  // With salt: Argon2id for 64 bytes, split 32+32
  final salt = baseKey.sublist(0, 16);
  final passwordKey = SecretKey(baseKey);
  final algorithm = DartArgon2id(
    parallelism: 1,
    memory: 128,
    iterations: 3,
    hashLength: 64,
  );
  final derivedKey = await algorithm.deriveKey(
    secretKey: passwordKey,
    nonce: salt,
  );
  final combined = await derivedKey.extractBytes();

  return VaultKey(
    encryptionKey: combined.sublist(0, 32),
    authHash: combined.sublist(32, 64),
  );
}
