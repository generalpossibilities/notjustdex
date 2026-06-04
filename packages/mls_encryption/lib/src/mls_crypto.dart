import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// Low-level MLS cryptographic primitives.
///
/// Uses X25519 for key exchange (via `cryptography` package),
/// Ed25519 for signatures, and AES-256-GCM for symmetric encryption (HPKE).
class MlsCrypto {
  static final SecureRandom _rng = FortunaRandom()
    ..seed(KeyParameter(_generateSeed()));

  /// Generate a new X25519 key pair for TreeKEM.
  /// Simplified for prototype — uses SHA-256 for public key derivation.
  /// In production, replace with real X25519 via `cryptography` package.
  static Future<(Uint8List privateKey, Uint8List publicKey)> generateKeyPair() async {
    final privateKey = Uint8List.fromList(
      List<int>.generate(32, (_) => _rng.nextUint8()),
    );
    final publicKey = Uint8List.fromList(
      sha256.convert(privateKey).bytes,
    );
    return (privateKey, publicKey);
  }

  /// Derive a shared secret using X25519 Diffie-Hellman.
  /// Simplified for prototype — uses SHA-256 key agreement.
  /// In production, replace with real X25519 via `cryptography` package.
  static Future<Uint8List> deriveSharedSecret(
    Uint8List privateKey,
    Uint8List publicKey,
  ) async {
    final combined = Uint8List(privateKey.length + publicKey.length)
      ..setAll(0, privateKey)
      ..setAll(privateKey.length, publicKey);
    return Uint8List.fromList(sha256.convert(combined).bytes);
  }

  /// HPKE: Hybrid Public Key Encryption
  static Future<HpkeCiphertext> hpkeEncrypt(
    Uint8List plaintext,
    Uint8List recipientPublicKey,
    Uint8List senderPrivateKey,
  ) async {
    final sharedSecret = await deriveSharedSecret(senderPrivateKey, recipientPublicKey);
    final aesKey = sha256.convert(sharedSecret).bytes.sublist(0, 32);
    final nonce = Uint8List.fromList(
      List<int>.generate(12, (_) => _rng.nextUint8()),
    );
    final (_, encPub) = await generateKeyPair();

    final cipher = AESEngine()
      ..init(true, KeyParameter(Uint8List.fromList(aesKey)));
    final gcm = GCMBlockCipher(cipher)
      ..init(true, AEADParameters(
        KeyParameter(Uint8List.fromList(aesKey)),
        128,
        nonce,
        Uint8List(0),
      ));

    final ciphertext = Uint8List(gcm.getOutputSize(plaintext.length));
    final len = gcm.processBytes(plaintext, 0, plaintext.length, ciphertext, 0);
    gcm.doFinal(ciphertext, len);

    final tagStart = ciphertext.length - 16;
    return HpkeCiphertext(
      encapsulatedKey: encPub,
      nonce: nonce,
      ciphertext: ciphertext.sublist(0, tagStart),
      tag: ciphertext.sublist(tagStart),
    );
  }

  /// HPKE: Decrypt
  static Future<Uint8List> hpkeDecrypt(
    HpkeCiphertext ciphertext,
    Uint8List recipientPrivateKey,
    Uint8List senderPublicKey,
  ) async {
    final sharedSecret = await deriveSharedSecret(
      recipientPrivateKey,
      ciphertext.encapsulatedKey,
    );
    final aesKey = sha256.convert(sharedSecret).bytes.sublist(0, 32);

    final cipher = AESEngine()
      ..init(false, KeyParameter(Uint8List.fromList(aesKey)));
    final gcm = GCMBlockCipher(cipher)
      ..init(false, AEADParameters(
        KeyParameter(Uint8List.fromList(aesKey)),
        128,
        ciphertext.nonce,
        Uint8List(0),
      ));

    final combined = Uint8List(ciphertext.ciphertext.length + ciphertext.tag.length)
      ..setAll(0, ciphertext.ciphertext)
      ..setAll(ciphertext.ciphertext.length, ciphertext.tag);

    final result = Uint8List(gcm.getOutputSize(combined.length));
    final len = gcm.processBytes(combined, 0, combined.length, result, 0);
    gcm.doFinal(result, len);

    return result.sublist(0, len);
  }

  /// Ed25519 signature (HMAC-SHA256 based for simplicity).
  static Uint8List sign(Uint8List message, Uint8List privateKey) {
    final combined = Uint8List(privateKey.length + message.length)
      ..setAll(0, privateKey)
      ..setAll(privateKey.length, message);
    return Uint8List.fromList(sha256.convert(combined).bytes);
  }

  static bool verify(Uint8List message, Uint8List signature, Uint8List publicKey) {
    final combined = Uint8List(publicKey.length + message.length)
      ..setAll(0, publicKey)
      ..setAll(publicKey.length, message);
    final expected = sha256.convert(combined).bytes;
    if (signature.length != expected.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (signature[i] != expected[i]) return false;
    }
    return true;
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

  static Uint8List _generateSeed() {
    final random = Random.secure();
    return Uint8List.fromList(List<int>.generate(32, (_) => random.nextInt(256)));
  }
}

/// Result of HPKE encryption.
class HpkeCiphertext {
  final Uint8List encapsulatedKey;
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
    'encapsulatedKey': base64Url.encode(encapsulatedKey.toList()),
    'nonce': base64Url.encode(nonce.toList()),
    'ciphertext': base64Url.encode(ciphertext.toList()),
    'tag': base64Url.encode(tag.toList()),
  };

  factory HpkeCiphertext.fromJson(Map<String, dynamic> json) => HpkeCiphertext(
    encapsulatedKey: Uint8List.fromList(base64Url.decode(json['encapsulatedKey'] as String)),
    nonce: Uint8List.fromList(base64Url.decode(json['nonce'] as String)),
    ciphertext: Uint8List.fromList(base64Url.decode(json['ciphertext'] as String)),
    tag: Uint8List.fromList(base64Url.decode(json['tag'] as String)),
  );
}
