import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'mls_crypto.dart';
import 'mls_exception.dart';

/// MLS Key Package — a pre-published bundle of public keys
/// that allows other members to add this user to a group.
///
/// Contains:
/// - X25519 public key (for TreeKEM key agreement)
/// - Ed25519 public key (for signing)
/// - Credential (user identity)
/// - Signature (self-signed to prove possession of private keys)
class MlsKeyPackage {
  final String userId;
  final List<int> encryptionPublicKey; // X25519
  final List<int> signaturePublicKey;  // Ed25519
  final List<int> signature;           // Self-signature
  final DateTime expiresAt;

  const MlsKeyPackage({
    required this.userId,
    required this.encryptionPublicKey,
    required this.signaturePublicKey,
    required this.signature,
    required this.expiresAt,
  });

  static MlsKeyPackage generate({
    required String userId,
    required List<int> encryptionPrivateKey,
    required List<int> signaturePrivateKey,
    required List<int> encryptionPublicKey,
    required List<int> signaturePublicKey,
  }) {
    // Self-sign the public keys
    final payload = utf8.encode(userId) +
        encryptionPublicKey +
        signaturePublicKey;
    final signature = MlsCrypto.sign(payload, signaturePrivateKey);

    return MlsKeyPackage(
      userId: userId,
      encryptionPublicKey: encryptionPublicKey,
      signaturePublicKey: signaturePublicKey,
      signature: signature,
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );
  }

  /// Verify the self-signature.
  bool verify() {
    final payload = utf8.encode(userId) +
        encryptionPublicKey +
        signaturePublicKey;
    return MlsCrypto.verify(payload, signature, signaturePublicKey);
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'encryption_public_key': base64Url.encode(encryptionPublicKey),
    'signature_public_key': base64Url.encode(signaturePublicKey),
    'signature': base64Url.encode(signature),
    'expires_at': expiresAt.toIso8601String(),
  };

  factory MlsKeyPackage.fromJson(Map<String, dynamic> json) => MlsKeyPackage(
    userId: json['user_id'] as String,
    encryptionPublicKey: base64Url.decode(json['encryption_public_key'] as String),
    signaturePublicKey: base64Url.decode(json['signature_public_key'] as String),
    signature: base64Url.decode(json['signature'] as String),
    expiresAt: DateTime.parse(json['expires_at'] as String),
  );
}

/// Local key store for a user.
class MlsKeyStore {
  final String userId;
  List<int> _encryptionPrivateKey;
  List<int> _signaturePrivateKey;
  List<int> _encryptionPublicKey;
  List<int> _signaturePublicKey;
  MlsKeyPackage? _currentKeyPackage;

  MlsKeyStore({
    required this.userId,
    required List<int> encryptionPrivateKey,
    required List<int> signaturePrivateKey,
    required List<int> encryptionPublicKey,
    required List<int> signaturePublicKey,
  })  : _encryptionPrivateKey = encryptionPrivateKey,
        _signaturePrivateKey = signaturePrivateKey,
        _encryptionPublicKey = encryptionPublicKey,
        _signaturePublicKey = signaturePublicKey;

  factory MlsKeyStore.generate(String userId) {
    final (encPriv, encPub) = MlsCrypto.generateKeyPair();
    final (sigPriv, sigPub) = MlsCrypto.generateKeyPair();

    return MlsKeyStore(
      userId: userId,
      encryptionPrivateKey: encPriv,
      signaturePrivateKey: sigPriv,
      encryptionPublicKey: encPub,
      signaturePublicKey: sigPub,
    );
  }

  MlsKeyPackage get keyPackage {
    if (_currentKeyPackage == null || _currentKeyPackage!.isExpired) {
      _currentKeyPackage = MlsKeyPackage.generate(
        userId: userId,
        encryptionPrivateKey: _encryptionPrivateKey,
        signaturePrivateKey: _signaturePrivateKey,
        encryptionPublicKey: _encryptionPublicKey,
        signaturePublicKey: _signaturePublicKey,
      );
    }
    return _currentKeyPackage!;
  }

  List<int> get encryptionPrivateKey => _encryptionPrivateKey;
  List<int> get signaturePrivateKey => _signaturePrivateKey;
  List<int> get encryptionPublicKey => _encryptionPublicKey;
  List<int> get signaturePublicKey => _signaturePublicKey;
}
