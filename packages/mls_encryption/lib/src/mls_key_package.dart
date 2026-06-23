import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'mls_crypto.dart';

class MlsKeyPackage {
  final String userId;
  final SimplePublicKey encryptionPublicKey;
  final SimplePublicKey signaturePublicKey;
  final Signature signature;
  final DateTime expiresAt;

  const MlsKeyPackage({
    required this.userId,
    required this.encryptionPublicKey,
    required this.signaturePublicKey,
    required this.signature,
    required this.expiresAt,
  });

  static Future<MlsKeyPackage> generate({
    required String userId,
    required SimplePublicKey encryptionPublicKey,
    required SimpleKeyPairData signatureKeyPair,
  }) async {
    final payload = Uint8List.fromList(
      utf8.encode(userId) + encryptionPublicKey.bytes.toList() + signatureKeyPair.publicKey.bytes.toList(),
    );
    final signature = await MlsCrypto.sign(payload, signatureKeyPair);

    return MlsKeyPackage(
      userId: userId,
      encryptionPublicKey: encryptionPublicKey,
      signaturePublicKey: signatureKeyPair.publicKey,
      signature: signature,
      expiresAt: DateTime.now().add(const Duration(days: 7)),
    );
  }

  Future<bool> verify() async {
    final payload = Uint8List.fromList(
      utf8.encode(userId) + encryptionPublicKey.bytes.toList() + signaturePublicKey.bytes.toList(),
    );
    return MlsCrypto.verify(payload, signature.bytes, signaturePublicKey);
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'encryption_public_key': base64Url.encode(encryptionPublicKey.bytes.toList()),
    'signature_public_key': base64Url.encode(signaturePublicKey.bytes.toList()),
    'signature': base64Url.encode(signature.bytes.toList()),
    'expires_at': expiresAt.toIso8601String(),
  };

  factory MlsKeyPackage.fromJson(Map<String, dynamic> json) => MlsKeyPackage(
    userId: json['user_id'] as String,
    encryptionPublicKey: SimplePublicKey(
      Uint8List.fromList(base64Url.decode(json['encryption_public_key'] as String)),
      type: KeyPairType.x25519,
    ),
    signaturePublicKey: SimplePublicKey(
      Uint8List.fromList(base64Url.decode(json['signature_public_key'] as String)),
      type: KeyPairType.ed25519,
    ),
    signature: Signature(
      Uint8List.fromList(base64Url.decode(json['signature'] as String)),
      publicKey: SimplePublicKey(
        Uint8List(0),
        type: KeyPairType.ed25519,
      ),
    ),
    expiresAt: DateTime.parse(json['expires_at'] as String),
  );
}

class MlsKeyStore {
  final String userId;
  SimpleKeyPairData _encryptionKeyPair;
  SimpleKeyPairData _signatureKeyPair;
  MlsKeyPackage? _currentKeyPackage;

  MlsKeyStore({
    required this.userId,
    required SimpleKeyPairData encryptionKeyPair,
    required SimpleKeyPairData signatureKeyPair,
  })  : _encryptionKeyPair = encryptionKeyPair,
        _signatureKeyPair = signatureKeyPair;

  static Future<MlsKeyStore> generate(String userId) async {
    final encKeyPair = await MlsCrypto.generateKeyPair();
    final sigKeyPair = await MlsCrypto.generateKeyPair();

    return MlsKeyStore(
      userId: userId,
      encryptionKeyPair: encKeyPair,
      signatureKeyPair: sigKeyPair,
    );
  }

  Future<MlsKeyPackage> get keyPackage async {
    if (_currentKeyPackage == null || _currentKeyPackage!.isExpired) {
      _currentKeyPackage = await MlsKeyPackage.generate(
        userId: userId,
        encryptionPublicKey: _encryptionKeyPair.publicKey,
        signatureKeyPair: _signatureKeyPair,
      );
    }
    return _currentKeyPackage!;
  }

  SimpleKeyPairData get encryptionKeyPair => _encryptionKeyPair;
  SimpleKeyPairData get signatureKeyPair => _signatureKeyPair;
  SimplePublicKey get encryptionPublicKey => _encryptionKeyPair.publicKey;
  SimplePublicKey get signaturePublicKey => _signatureKeyPair.publicKey;
}
