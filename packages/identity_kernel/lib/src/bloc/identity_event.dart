import 'package:freezed_annotation/freezed_annotation.dart';

part 'identity_event.freezed.dart';

@freezed
class IdentityEvent with _$IdentityEvent {
  /// Register with passkey (decentralized, on-chain).
  const factory IdentityEvent.registerWithPasskey({
    required String passkeyCredentialId,
    required String passkeyPublicKey,
    required String username,
    required String displayName,
    String? phoneNumber,
  }) = RegisterWithPasskey;

  /// Login with passkey (passkey assertion + chain verify).
  const factory IdentityEvent.loginWithPasskey({
    required String passkeyCredentialId,
    required String passkeySignature,
  }) = LoginWithPasskey;

  /// Login with wallet signature (ZKP alternative).
  const factory IdentityEvent.loginWithWallet({
    required String address,
    required List<int> signature,
    required List<int> challenge,
  }) = LoginWithWallet;

  /// Load identity from chain (fallback to local cache).
  const factory IdentityEvent.loadIdentity(String identityId) = LoadIdentity;

  /// Update profile metadata.
  const factory IdentityEvent.updateProfile({
    required String identityId,
    required String displayName,
    required String bio,
    String? avatarCid,
  }) = UpdateProfile;

  /// Resolve username to identity.
  const factory IdentityEvent.resolveUsername(String username) =
      ResolveUsername;

  /// Check username availability on chain.
  const factory IdentityEvent.checkAvailability(String username) =
      CheckAvailability;

  /// Refresh current identity from chain.
  const factory IdentityEvent.refresh() = RefreshIdentity;

  /// Logout (clear session).
  const factory IdentityEvent.logout() = Logout;
}
