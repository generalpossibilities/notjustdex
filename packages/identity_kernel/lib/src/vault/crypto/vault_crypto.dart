import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import '../models/vault_entry.dart';

const int _nonceLen = 24;
const int _macLen = 16;

class EncryptedVault {
  final List<int> nonce;
  final List<int> ciphertext;
  final List<int> mac;

  const EncryptedVault({
    required this.nonce,
    required this.ciphertext,
    required this.mac,
  });
}

Future<EncryptedVault> encryptVault(
  List<VaultEntry> entries,
  List<int> encryptionKey,
) async {
  final rand = Random.secure();
  final nonce = List<int>.generate(_nonceLen, (_) => rand.nextInt(256));
  final plaintext = utf8.encode(VaultEntry.serializeList(entries));

  final algorithm = Xchacha20.poly1305Aead();
  final secretBox = await algorithm.encrypt(
    plaintext,
    secretKey: SecretKey(encryptionKey),
    nonce: nonce,
  );

  return EncryptedVault(
    nonce: secretBox.nonce,
    ciphertext: secretBox.cipherText,
    mac: secretBox.mac.bytes,
  );
}

Future<List<VaultEntry>?> decryptVault(
  EncryptedVault encrypted,
  List<int> encryptionKey,
) async {
  try {
    final algorithm = Xchacha20.poly1305Aead();
    final secretBox = SecretBox(
      encrypted.ciphertext,
      nonce: encrypted.nonce,
      mac: Mac(encrypted.mac),
    );
    final plaintext = await algorithm.decrypt(
      secretBox,
      secretKey: SecretKey(encryptionKey),
    );
    return VaultEntry.deserializeList(utf8.decode(plaintext));
  } catch (_) {
    return null;
  }
}

List<int> serializeVault(EncryptedVault encrypted) {
  return [
    ...encrypted.nonce,
    ...encrypted.ciphertext,
    ...encrypted.mac,
  ];
}

EncryptedVault deserializeVault(List<int> data) {
  if (data.length < _nonceLen + _macLen) {
    throw ArgumentError('Data too short for vault deserialization');
  }
  final nonce = data.sublist(0, _nonceLen);
  final ciphertext = data.sublist(_nonceLen, data.length - _macLen);
  final mac = data.sublist(data.length - _macLen);
  return EncryptedVault(nonce: nonce, ciphertext: ciphertext, mac: mac);
}
