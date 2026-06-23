import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import '../models/vault_entry.dart';
import '../crypto/vault_crypto.dart';

class VaultBackupService {
  Future<String> exportBackup({
    required List<VaultEntry> entries,
    required String password,
  }) async {
    final rand = Random.secure();
    final salt = List<int>.generate(32, (_) => rand.nextInt(256));
    final nonce = List<int>.generate(24, (_) => rand.nextInt(256));

    final key = await _deriveBackupKey(password, salt);
    final plaintext = utf8.encode(VaultEntry.serializeList(entries));

    final algorithm = Xchacha20.poly1305Aead();
    final secretBox = await algorithm.encrypt(
      plaintext,
      secretKey: SecretKey(key),
      nonce: nonce,
    );

    final backup = {
      'version': 2,
      'algorithm': 'XChaCha20-Poly1305',
      'kdf': 'Argon2id',
      'salt': base64.encode(salt),
      'nonce': base64.encode(secretBox.nonce),
      'ciphertext': base64.encode(secretBox.cipherText),
      'mac': base64.encode(secretBox.mac.bytes),
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'entryCount': entries.length,
    };

    return base64.encode(utf8.encode(jsonEncode(backup)));
  }

  Future<List<VaultEntry>?> importBackup({
    required String backupData,
    required String password,
  }) async {
    try {
      final decoded = utf8.decode(base64.decode(backupData));
      final json = jsonDecode(decoded) as Map<String, dynamic>;

      if (json['version'] != 2) {
        throw ArgumentError('Unsupported backup version: ${json['version']}');
      }

      final salt = base64.decode(json['salt'] as String);
      final nonce = base64.decode(json['nonce'] as String);
      final ciphertext = base64.decode(json['ciphertext'] as String);
      final macBytes = base64.decode(json['mac'] as String);

      final key = await _deriveBackupKey(password, salt);

      final algorithm = Xchacha20.poly1305Aead();
      final secretBox = SecretBox(
        ciphertext,
        nonce: nonce,
        mac: Mac(macBytes),
      );
      final plaintext = await algorithm.decrypt(
        secretBox,
        secretKey: SecretKey(key),
      );

      return VaultEntry.deserializeList(utf8.decode(plaintext));
    } catch (_) {
      return null;
    }
  }

  Future<List<int>> _deriveBackupKey(String password, List<int> salt) async {
    final algorithm = DartArgon2id(
      parallelism: 4,
      memory: 65536,
      iterations: 3,
      hashLength: 32,
    );

    final derivedKey = await algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );

    return derivedKey.extractBytes();
  }
}
