class PasskeyException implements Exception {
  final String code;
  final String message;

  const PasskeyException(this.code, this.message);

  factory PasskeyException.notSupported() =>
      PasskeyException('not_supported', 'Passkeys are not supported on this device');

  factory PasskeyException.cancelled() =>
      PasskeyException('cancelled', 'User cancelled passkey operation');

  factory PasskeyException.timeout() =>
      PasskeyException('timeout', 'Passkey operation timed out');

  factory PasskeyException.notFound() =>
      PasskeyException('not_found', 'No matching passkey found');

  @override
  String toString() => 'PasskeyException($code): $message';
}
