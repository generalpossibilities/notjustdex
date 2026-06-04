import 'dart:convert';
import 'dart:typed_data';
import 'mls_crypto.dart';

/// MLS Key Package — pre-published public keys for group addition.
class MlsKeyPackage {
  final String userId;
  final Uint8List encryptionPublicKey;
  final Uint8List signaturePublicKey;
  final Uint8List signature;
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
    required Uint8List encryptionPublicKey,
    required Uint8List signaturePrivateKey,
    required Uint8List signaturePublicKey,
  }) {
    final payload = Uint8List.fromList(
      utf8.encode(userId) + encryptionPublicKey.toList() + signaturePublicKey.toList(),
    );
    final signature = MlsCrypto.sign(payload, signaturePrivateKey);

    return MlsKeyPackage(
      userId: userId,
      encryptionPublicKey: encryptionPublicKey,
      signaturePublicKey: signaturePublicKey,
      signature: signature,
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );
  }

  bool verify() {
    final payload = Uint8List.fromList(
      utf8.encode(userId) + encryptionPublicKey.toList() + signaturePublicKey.toList(),
    );
    return MlsCrypto.verify(payload, signature, signaturePublicKey);
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'encryption_public_key': base64Url.encode(encryptionPublicKey.toList()),
    'signature_public_key': base64Url.encode(signaturePublicKey.toList()),
    'signature': base64Url.encode(signature.toList()),
    'expires_at': expiresAt.toIso8601String(),
  };

  factory MlsKeyPackage.fromJson(Map<String, dynamic> json) => MlsKeyPackage(
    userId: json['user_id'] as String,
    encryptionPublicKey: Uint8List.fromList(base64Url.decode(json['encryption_public_key'] as String)),
    signaturePublicKey: Uint8List.fromList(base64Url.decode(json['signature_public_key'] as String)),
    signature: Uint8List.fromList(base64Url.decode(json['signature'] as String)),
    expiresAt: DateTime.parse(json['expires_at'] as String),
  );
}

/// Local key store for a user.
class MlsKeyStore {
  final String userId;
  Uint8List _encryptionPrivateKey;
  Uint8List _signaturePrivateKey;
  Uint8List _encryptionPublicKey;
  Uint8List _signaturePublicKey;
  MlsKeyPackage? _currentKeyPackage;

  MlsKeyStore({
    required this.userId,
    required Uint8List encryptionPrivateKey,
    required Uint8List signaturePrivateKey,
    required Uint8List encryptionPublicKey,
    required Uint8List signaturePublicKey,
  })  : _encryptionPrivateKey = encryptionPrivateKey,
        _signaturePrivateKey = signaturePrivateKey,
        _encryptionPublicKey = encryptionPublicKey,
        _signaturePublicKey = signaturePublicKey;

  static Future<MlsKeyStore> generate(String userId) async {
    final (encPriv, encPub) = await MlsCrypto.generateKeyPair();
    final (sigPriv, sigPub) = await MlsCrypto.generateKeyPair();

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
        encryptionPublicKey: _encryptionPublicKey,
        signaturePrivateKey: _signaturePrivateKey,
        signaturePublicKey: _signaturePublicKey,
      );
    }
    return _currentKeyPackage!;
  }

  Uint8List get encryptionPrivateKey => _encryptionPrivateKey;
  Uint8List get signaturePrivateKey => _signaturePrivateKey;
  Uint8List get encryptionPublicKey => _encryptionPublicKey;
  Uint8List get signaturePublicKey => _signaturePublicKey;
}
