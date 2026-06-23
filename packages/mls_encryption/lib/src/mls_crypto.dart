import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' show sha256, Hmac;
import 'package:cryptography/cryptography.dart';

class MlsCrypto {
  static final _ed25519 = Ed25519();
  static final _x25519 = X25519();
  static final _aesGcm = AesGcm.with256bits();
  static final _rand = Random.secure();

  static Future<SimpleKeyPairData> generateKeyPair() async {
    final keyPair = await _x25519.newKeyPair();
    return keyPair.extract();
  }

  static Future<SimpleKeyPairData> generateKeyPairFromSeed(Uint8List seed) async {
    final keyPair = await _x25519.newKeyPairFromSeed(seed.toList());
    return keyPair.extract();
  }

  static Future<SimpleKeyPairData> generateSigningKeyPairFromSeed(Uint8List seed) async {
    final keyPair = await _ed25519.newKeyPairFromSeed(seed.toList());
    return keyPair.extract();
  }

  static Uint8List deriveKey(Uint8List seed, String label) {
    final hmac = Hmac(sha256, seed);
    return Uint8List.fromList(hmac.convert(utf8.encode(label)).bytes);
  }

  static Future<SecretKey> deriveSharedSecret(
    SimpleKeyPairData privateKey,
    SimplePublicKey publicKey,
  ) async {
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: SimpleKeyPairData(
        privateKey.bytes,
        publicKey: privateKey.publicKey,
        type: KeyPairType.x25519,
      ),
      remotePublicKey: publicKey,
    );
    return sharedSecret;
  }

  static Future<HpkeCiphertext> hpkeEncrypt(
    Uint8List plaintext,
    SimplePublicKey recipientPublicKey,
    SimpleKeyPairData senderKeyPair,
  ) async {
    final sharedSecret = await deriveSharedSecret(senderKeyPair, recipientPublicKey);
    final nonce = Uint8List.fromList(
      List<int>.generate(12, (_) => _rand.nextInt(256)),
    );

    final senderPub = senderKeyPair.publicKey;
    final secretBox = await _aesGcm.encrypt(
      plaintext,
      secretKey: sharedSecret,
      nonce: nonce,
    );

    return HpkeCiphertext(
      encapsulatedKey: senderPub,
      nonce: nonce,
      ciphertext: Uint8List.fromList(secretBox.cipherText),
      tag: Uint8List.fromList(secretBox.mac.bytes),
    );
  }

  static Future<Uint8List> hpkeDecrypt(
    HpkeCiphertext ciphertext,
    SimpleKeyPairData recipientKeyPair,
    SimplePublicKey senderPublicKey,
  ) async {
    final sharedSecret = await deriveSharedSecret(
      recipientKeyPair,
      ciphertext.encapsulatedKey,
    );

    final secretBox = SecretBox(
      ciphertext.ciphertext,
      nonce: ciphertext.nonce,
      mac: Mac(ciphertext.tag),
    );

    final plaintext = await _aesGcm.decrypt(
      secretBox,
      secretKey: sharedSecret,
    );

    return Uint8List.fromList(plaintext);
  }

  static Future<Signature> sign(
    Uint8List message,
    SimpleKeyPairData keyPair,
  ) async {
    return _ed25519.sign(message, keyPair: keyPair);
  }

  static Future<bool> verify(
    Uint8List message,
    Uint8List signatureBytes,
    SimplePublicKey publicKey,
  ) async {
    final sig = Signature(
      signatureBytes,
      publicKey: publicKey,
    );
    return _ed25519.verify(message, signature: sig);
  }

  static Uint8List hashRatchet(Uint8List key, int generation) {
    final data = Uint8List(key.length + 8);
    data.setAll(0, key);
    for (var i = 0; i < 8; i++) {
      data[key.length + i] = (generation >> (i * 8)) & 0xFF;
    }
    return Uint8List.fromList(sha256.convert(data).bytes);
  }

  static Uint8List deriveEncryptionKey(Uint8List leafKey, String label) {
    final data = Uint8List.fromList(utf8.encode(label) + leafKey.toList());
    return Uint8List.fromList(sha256.convert(data).bytes);
  }
}

class HpkeCiphertext {
  final SimplePublicKey encapsulatedKey;
  final Uint8List nonce;
  final Uint8List ciphertext;
  final Uint8List tag;

  const HpkeCiphertext({
    required this.encapsulatedKey,
    required this.nonce,
    required this.ciphertext,
    required this.tag,
  });

  Map<String, dynamic> toJson() => {
    'encapsulatedKey': base64Url.encode(encapsulatedKey.bytes.toList()),
    'nonce': base64Url.encode(nonce.toList()),
    'ciphertext': base64Url.encode(ciphertext.toList()),
    'tag': base64Url.encode(tag.toList()),
  };

  factory HpkeCiphertext.fromJson(Map<String, dynamic> json) => HpkeCiphertext(
    encapsulatedKey: SimplePublicKey(
      Uint8List.fromList(base64Url.decode(json['encapsulatedKey'] as String)),
      type: KeyPairType.x25519,
    ),
    nonce: Uint8List.fromList(base64Url.decode(json['nonce'] as String)),
    ciphertext: Uint8List.fromList(base64Url.decode(json['ciphertext'] as String)),
    tag: Uint8List.fromList(base64Url.decode(json['tag'] as String)),
  );
}
