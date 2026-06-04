import 'dart:convert';

/// Abstracts WebAuthn (passkey) platform API.
/// On Android: uses Credential Manager / FIDO2
/// On iOS: uses ASAuthorizationController
/// On Web: uses navigator.credentials.create/get
///
/// This is a stub — in production, use platform channels
/// or a package like `passkeys` / `corbados_auth`.
class PasskeyService {
  /// Create a new passkey credential.
  /// Returns [credentialId, publicKey] as base64url-encoded strings.
  Future<List<String>> createCredential({
    required String userId,
    required String userName,
    required Map<String, dynamic> options,
  }) async {
    // In production:
    //   1. Convert options to PlatformCredentialCreationOptions
    //   2. Call PlatformChannel (e.g., CredentialManager.createCredential)
    //   3. Return (credentialId, publicKey)
    //
    // Stub: simulate a successful credential creation.
    final mockId = base64Encode(utf8.encode('mock_passkey_$userId'));
    final mockKey = base64Encode(utf8.encode(
      '{"kty":"EC","crv":"P-256","x":"mock_x","y":"mock_y"}',
    ));
    return [mockId, mockKey];
  }

  /// Authenticate with an existing passkey credential.
  /// Returns [credentialId, signCount] or throws if no passkey available.
  Future<List<dynamic>> getAssertion({
    required Map<String, dynamic> options,
  }) async {
    // In production:
    //   1. Convert options to PlatformCredentialRequestOptions
    //   2. Call PlatformChannel (e.g., CredentialManager.getCredential)
    //   3. Return (credentialId, authenticatorData, signature, userHandle)
    //
    // Stub: simulate successful assertion.
    return [
      base64Encode(utf8.encode('mock_passkey_user')),
      1, // signCount
    ];
  }

  /// Check if the device supports passkeys.
  Future<bool> isSupported() async {
    // In production: check CredentialManager.isAvailable
    return true;
  }
}
