class MlsException implements Exception {
  final String code;
  final String message;

  const MlsException(this.code, this.message);

  factory MlsException.invalidKeyPackage() =>
      const MlsException('invalid_key_package', 'Invalid or expired key package');

  factory MlsException.groupNotFound() =>
      const MlsException('group_not_found', 'MLS group not found');

  factory MlsException.notMember() =>
      const MlsException('not_member', 'User is not a member of this group');

  factory MlsException.encryptionFailed() =>
      const MlsException('encryption_failed', 'Failed to encrypt message');

  factory MlsException.decryptionFailed() =>
      const MlsException('decryption_failed', 'Failed to decrypt message');

  factory MlsException.invalidSignature() =>
      const MlsException('invalid_signature', 'Message signature is invalid');

  @override
  String toString() => 'MlsException($code): $message';
}
