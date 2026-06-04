import 'package:freezed_annotation/freezed_annotation.dart';

part 'identity_event.freezed.dart';

@freezed
class IdentityEvent with _$IdentityEvent {
  const factory IdentityEvent.createIdentity({
    required String phoneNumber,
    required String username,
    required String displayName,
  }) = CreateIdentity;

  const factory IdentityEvent.loadIdentity(String identityId) = LoadIdentity;

  const factory IdentityEvent.updateProfile({
    required String identityId,
    required String displayName,
    required String bio,
    String? avatarUrl,
  }) = UpdateProfile;

  const factory IdentityEvent.resolveUsername(String username) =
      ResolveUsername;

  const factory IdentityEvent.checkAvailability(String username) =
      CheckAvailability;

  const factory IdentityEvent.refresh() = RefreshIdentity;

  const factory IdentityEvent.logout() = Logout;
}
