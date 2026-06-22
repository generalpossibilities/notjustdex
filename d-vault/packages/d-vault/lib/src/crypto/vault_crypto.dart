import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import '../models/vault_entry.dart';

const int _nonceLen = 24;
const int _macLen = 16;

Future<EncryptedVault> encryptVault(
  List<PlaintextEntry> entries,
  List<int> encryptionKey,
) async {
  final rand = Random.secure();
  final nonce = List<int>.generate(_nonceLen, (_) => rand.nextInt(256));
  final plaintext = utf8.encode(jsonEncode(entries.map((e) => e.toJson()).toList()));

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

Future<List<PlaintextEntry>?> decryptVault(
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
    final decoded = utf8.decode(plaintext);
    final list = jsonDecode(decoded) as List<dynamic>;
    return list.map((e) => PlaintextEntry.fromJson(e as Map<String, dynamic>)).toList();
  } catch (_) {
    return null;
  }
}

List<int> serializeVault(EncryptedVault encrypted) {
  final payload = List<int>.of(encrypted.nonce)
    ..addAll(encrypted.ciphertext)
    ..addAll(encrypted.mac);
  return payload;
}

EncryptedVault deserializeVault(List<int> data) {
  final nonce = data.sublist(0, _nonceLen);
  final ciphertext = data.sublist(_nonceLen, data.length - _macLen);
  final mac = data.sublist(data.length - _macLen);
  return EncryptedVault(nonce: nonce, ciphertext: ciphertext, mac: mac);
}
