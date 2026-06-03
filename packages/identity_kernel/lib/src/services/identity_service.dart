import 'dart:async';
import '../models/user_identity.dart';
import '../models/username.dart';
import '../models/profile.dart';
import '../repositories/identity_repository.dart';
import '../exceptions.dart';

class IdentityService {
  final IdentityRepository _repository;

  IdentityService(this._repository);

  Future<UserIdentity> createIdentity({
    required String phoneNumber,
    required String username,
    required String displayName,
  }) async {
    final validatedUsername = Username.tryCreate(username);
    if (validatedUsername == null) {
      throw IdentityException('Invalid username format');
    }

    final availability = await _repository.checkUsernameAvailability(username);
    if (!availability) {
      throw IdentityException('Username already taken on chain');
    }

    final identity = await _repository.createIdentity(
      phoneNumber: phoneNumber,
      username: validatedUsername.value,
      displayName: displayName,
    );

    return identity;
  }

  Future<UserIdentity> getIdentity(String identityId) async {
    final identity = await _repository.getIdentity(identityId);
    if (identity == null) {
      throw IdentityException('Identity not found');
    }
    return identity;
  }

  Future<UserIdentity> updateProfile(
    String identityId,
    Profile profile,
  ) async {
    return _repository.updateProfile(identityId, profile);
  }

  Future<UserIdentity> resolveUsername(String username) async {
    final identity = await _repository.resolveUsername(username.toLowerCase());
    if (identity == null) {
      throw IdentityException('Username not found');
    }
    return identity;
  }

  Future<bool> checkUsernameAvailability(String username) {
    return _repository.checkUsernameAvailability(username.toLowerCase());
  }

  Stream<UserIdentity> watchIdentity(String identityId) {
    return _repository.watchIdentity(identityId);
  }
}
