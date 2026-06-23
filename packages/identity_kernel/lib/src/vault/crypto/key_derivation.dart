import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

const String _domainSep = 'notjustdex-dvault-v2';

class VaultKey {
  final List<int> encryptionKey;
  final List<int> authHash;

  const VaultKey({
    required this.encryptionKey,
    required this.authHash,
  });
}

Future<VaultKey> deriveVaultKey({
  required String username,
  String? saltPassword,
}) async {
  final baseSecret = utf8.encode('$_domainSep|$username|${saltPassword ?? ''}');
  final baseHash = await Sha256().hash(baseSecret);
  final ikm = baseHash.bytes;

  final salt = utf8.encode(username.padRight(16, '0').substring(0, 16));

  const algorithm = DartArgon2id(
    parallelism: 4,
    memory: 65536,
    iterations: 3,
    hashLength: 64,
  );

  final derivedKey = await algorithm.deriveKey(
    secretKey: SecretKey(ikm),
    nonce: salt,
  );

  final combined = await derivedKey.extractBytes();

  return VaultKey(
    encryptionKey: combined.sublist(0, 32),
    authHash: combined.sublist(32, 64),
  );
}
