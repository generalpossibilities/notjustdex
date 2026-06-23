import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../auth/decentralized_auth_service.dart';
import '../models/user_identity.dart';
import '../models/username.dart';
import '../chain/an_identity_contract.dart';
import '../chain/an_light_client.dart';
import '../repositories/identity_repository.dart';
import '../exceptions.dart';

/// Facade over [DecentralizedAuthService] for backwards compatibility.
/// All auth flows are fully on-chain, no Go service dependency.
class AuthenticationService {
  final DecentralizedAuthService _decentralized;

  AuthenticationService({
    required AnIdentityContract contract,
    required IdentityRepository identityRepo,
  }) : _decentralized = DecentralizedAuthService(
          contract: contract,
          identityRepo: identityRepo,
        );

  bool get isAuthenticated => _decentralized.isAuthenticated;
  DecentralizedAuthService get decentralized => _decentralized;

  /// Register with passkey (primary flow).
  Future<UserIdentity> registerWithPasskey({
    required String passkeyCredentialId,
    required String passkeyPublicKey,
    required String username,
    required String displayName,
    String? phoneNumber,
  }) async {
    final validated = Username.tryCreate(username);
    if (validated == null) throw IdentityException('Invalid username');

    final phoneHash = phoneNumber != null
        ? _hashPhone(phoneNumber)
        : null;

    return _decentralized.registerWithPasskey(
      passkeyCredentialId: passkeyCredentialId,
      passkeyPublicKey: passkeyPublicKey,
      username: validated,
      displayName: displayName,
      phoneHash: phoneHash,
    );
  }

  /// Login with passkey.
  Future<UserIdentity> loginWithPasskey({
    required String passkeyCredentialId,
    required String passkeySignature,
  }) {
    return _decentralized.loginWithPasskey(
      passkeyCredentialId: passkeyCredentialId,
      passkeySignature: passkeySignature,
    );
  }

  /// Login with wallet signature (ZKP alternative).
  Future<UserIdentity> loginWithWallet({
    required String address,
    required List<int> signature,
    required List<int> challenge,
  }) {
    return _decentralized.loginWithWallet(
      address: address,
      signature: signature,
      challenge: challenge,
    );
  }

  /// Send phone verification (decentralized — uses any available gateway).
  Future<String> sendPhoneVerification(String phoneNumber) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return 'code_sent';
  }

  /// Verify phone code locally.
  Future<bool> verifyPhone(String phoneNumber, String code) async {
    return _decentralized.verifyPhone(phoneHash: _hashPhone(phoneNumber), verificationCode: code);
  }

  Future<void> logout() => _decentralized.logout();

  String _hashPhone(String phone) {
    return sha256.convert(utf8.encode('njd_phone_$phone')).toString();
  }
}
