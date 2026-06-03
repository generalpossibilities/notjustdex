class IdentityException implements Exception {
  final String message;
  const IdentityException(this.message);

  @override
  String toString() => 'IdentityException: $message';
}

class WalletException implements Exception {
  final String message;
  const WalletException(this.message);

  @override
  String toString() => 'WalletException: $message';
}

class RecoveryException implements Exception {
  final String message;
  const RecoveryException(this.message);

  @override
  String toString() => 'RecoveryException: $message';
}

class AuthenticationException implements Exception {
  final String message;
  const AuthenticationException(this.message);

  @override
  String toString() => 'AuthenticationException: $message';
}
