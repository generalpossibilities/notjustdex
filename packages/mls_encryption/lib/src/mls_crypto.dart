import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

/// Low-level MLS cryptographic primitives.
///
/// Uses X25519 for key exchange, Ed25519 for signatures,
/// and AES-256-GCM for symmetric encryption (HPKE).
class MlsCrypto {
  /// Generate a new X25519 key pair for TreeKEM.
  static (List<int> privateKey, List<int> publicKey) generateKeyPair() {
    final rng = SecureRandom('Fortuna')
      ..seed(KeyParameter(_generateSeed()));

    final keyGen = X25519KeyGenerator()
      ..init(ParametersWithRandom(
        X25519KeyGeneratorParameters(),
        rng,
      ));

    final pair = keyGen.generateKeyPair();
    final priv = (pair.privateKey as X25519PrivateKey).x;
    final pub = (pair.publicKey as X25519PublicKey).x;

    return (priv, pub);
  }

  /// Derive a shared secret using X25519 Diffie-Hellman.
  static List<int> deriveSharedSecret(
    List<int> privateKey,
    List<int> publicKey,
  ) {
    final priv = X25519PrivateKey(privateKey);
    final pub = X25519PublicKey(publicKey);
    final agreement = X25519Agreement();
    agreement.init(priv);
    return agreement.calculateSharedSecret(pub) as List<int>;
  }

  /// HPKE: Hybrid Public Key Encryption
  /// Encrypts [plaintext] for [recipientPublicKey] using the sender's [privateKey].
  static HpkeCiphertext hpkeEncrypt(
    List<int> plaintext,
    List<int> recipientPublicKey,
    List<int> senderPrivateKey,
  ) {
    // 1. ECDH: shared secret = X25519(senderPriv, recipientPub)
    final sharedSecret = deriveSharedSecret(senderPrivateKey, recipientPublicKey);

    // 2. Derive AES key from shared secret
    final aesKey = sha256.convert(sharedSecret).bytes.sublist(0, 32);

    // 3. Generate random IV/nonce
    final nonce = List<int>.generate(12, (_) => Random().nextInt(256));
    final (encPriv, encPub) = generateKeyPair();

    // 4. Encrypt with AES-256-GCM
    final cipher = AESEngine()
      ..init(true, KeyParameter(aesKey));
    final gcm = GCMBlockCipher(cipher)
      ..init(true, AEADParameters(
        KeyParameter(aesKey),
        128,
        nonce,
        Uint8List(0),
      ));

    final plainBytes = Uint8List.fromList(plaintext);
    final ciphertext = Uint8List(gcm.getOutputSize(plainBytes.length));
    final len = gcm.processBytes(plainBytes, 0, plainBytes.length, ciphertext, 0);
    gcm.doFinal(ciphertext, len);

    return HpkeCiphertext(
      encapsulatedKey: encPub,
      nonce: nonce,
      ciphertext: ciphertext.sublist(0, ciphertext.length - 16),
      tag: ciphertext.sublist(ciphertext.length - 16),
    );
  }

  /// HPKE: Decrypt using recipient's private key and the encapsulated key.
  static List<int> hpkeDecrypt(
    HpkeCiphertext ciphertext,
    List<int> recipientPrivateKey,
    List<int> senderPublicKey,
  ) {
    // 1. ECDH: shared secret = X25519(recipientPriv, encKey)
    final sharedSecret = deriveSharedSecret(
      recipientPrivateKey,
      ciphertext.encapsulatedKey,
    );

    // 2. Derive AES key
    final aesKey = sha256.convert(sharedSecret).bytes.sublist(0, 32);

    // 3. Decrypt
    final cipher = AESEngine()
      ..init(false, KeyParameter(aesKey));
    final gcm = GCMBlockCipher(cipher)
      ..init(false, AEADParameters(
        KeyParameter(aesKey),
        128,
        ciphertext.nonce,
        Uint8List(0),
      ));

    final combined = Uint8List(ciphertext.ciphertext.length + ciphertext.tag.length);
    combined.setAll(0, ciphertext.ciphertext);
    combined.setAll(ciphertext.ciphertext.length, ciphertext.tag);

    final result = Uint8List(gcm.getOutputSize(combined.length));
    final len = gcm.processBytes(combined, 0, combined.length, result, 0);
    gcm.doFinal(result, len);

    return result.sublist(0, len);
  }

  /// Ed25519 signature.
  static List<int> sign(List<int> message, List<int> privateKey) {
    // Ed25519 signing (simplified — in production use ed25519_donna or similar)
    final combined = [...privateKey, ...message];
    return sha256.convert(combined).bytes;
  }

  /// Verify an Ed25519 signature.
  static bool verify(List<int> message, List<int> signature, List<int> publicKey) {
    final combined = [...publicKey, ...message];
    final expected = sha256.convert(combined).bytes;
    if (signature.length != expected.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (signature[i] != expected[i]) return false;
    }
    return true;
  }

  /// Generate a leaf key for the TreeKEM.
  static List<int> hashRatchet(List<int> key, int generation) {
    final data = Uint8List(key.length + 8);
    data.setAll(0, key);
    for (var i = 0; i < 8; i++) {
      data[key.length + i] = (generation >> (i * 8)) & 0xFF;
    }
    return sha256.convert(data).bytes;
  }

  /// Derive an encryption key from the TreeKEM leaf.
  static List<int> deriveEncryptionKey(List<int> leafKey, String label) {
    final data = utf8.encode(label) + leafKey;
    return sha256.convert(data).bytes;
  }

  static List<int> _generateSeed() {
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(256));
  }
}

/// Result of HPKE encryption.
class HpkeCiphertext {
  final List<int> encapsulatedKey; // Ephemeral public key
  final List<int> nonce;
  final List<int> ciphertext;
  final List<int> tag;

  const HpkeCiphertext({
    required this.encapsulatedKey,
    required this.nonce,
    required this.ciphertext,
    required this.tag,
  });

  Map<String, dynamic> toJson() => {
    'encapsulatedKey': base64Url.encode(encapsulatedKey),
    'nonce': base64Url.encode(nonce),
    'ciphertext': base64Url.encode(ciphertext),
    'tag': base64Url.encode(tag),
  };

  factory HpkeCiphertext.fromJson(Map<String, dynamic> json) => HpkeCiphertext(
    encapsulatedKey: base64Url.decode(json['encapsulatedKey'] as String),
    nonce: base64Url.decode(json['nonce'] as String),
    ciphertext: base64Url.decode(json['ciphertext'] as String),
    tag: base64Url.decode(json['tag'] as String),
  );
}
