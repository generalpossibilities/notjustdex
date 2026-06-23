import 'dart:async';
import '../models/user_identity.dart';
import '../models/profile.dart';

abstract class IdentityRepository {
  Future<UserIdentity> createIdentity({
    required String phoneNumber,
    required String username,
    required String displayName,
  });

  Future<UserIdentity?> getIdentity(String identityId);

  Future<UserIdentity?> resolveUsername(String username);

  Future<bool> checkUsernameAvailability(String username);

  Future<UserIdentity> updateProfile(
    String identityId,
    Profile profile,
  );

  /// Save identity to local cache.
  Future<void> saveIdentity(UserIdentity identity);

  Stream<UserIdentity> watchIdentity(String identityId);
}
