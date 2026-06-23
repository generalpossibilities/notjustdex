import 'dart:async';
import '../models/user_identity.dart';
import '../models/username.dart';
import '../models/profile.dart';
import '../chain/an_identity_contract.dart';
import '../repositories/identity_repository.dart';
import '../exceptions.dart';

/// Identity service — fully on-chain. No Go relay.
///
/// All identity operations go directly to Acki Nacki chain
/// through [AnIdentityContract]. The [IdentityRepository] is
/// used for local caching only.
class IdentityService {
  final AnIdentityContract _contract;
  final IdentityRepository _cache;

  IdentityService({
    required AnIdentityContract contract,
    required IdentityRepository cache,
  })  : _contract = contract,
        _cache = cache;

  /// Check if a username is available on chain.
  Future<bool> checkUsernameAvailability(String username) {
    return _contract.isUsernameAvailable(username.toLowerCase());
  }

  /// Resolve username to identity (from chain).
  Future<UserIdentity> resolveUsername(String username) async {
    final identity = await _contract.resolveUsername(username.toLowerCase());
    if (identity == null) {
      throw IdentityException('Username not found on chain: $username');
    }
    await _cache.saveIdentity(identity);
    return identity;
  }

  /// Get identity by wallet address (from chain, fallback to cache).
  Future<UserIdentity> getIdentity(String address) async {
    final chain = await _contract.getIdentity(address);
    if (chain != null) {
      await _cache.saveIdentity(chain);
      return chain;
    }
    final cached = await _cache.getIdentity(address);
    if (cached != null) return cached;
    throw IdentityException('Identity not found: $address');
  }

  /// Update profile metadata (update IPFS CID on chain).
  Future<UserIdentity> updateProfile(
    String identityAddress,
    Profile profile,
  ) async {
    // In production: upload profile JSON to IPFS, get CID,
    // then commit CID to chain via updateIdentityRoot.
    // For now, update local cache.
    final updated = UserIdentity(
      id: identityAddress,
      username: Username(profile.username),
      profile: profile,
      wallet: (await getIdentity(identityAddress)).wallet,
      authMethods: [],
      createdAt: DateTime.now(),
    );
    await _cache.saveIdentity(updated);
    return updated;
  }

  /// Watch identity for changes (from chain events).
  Stream<UserIdentity> watchIdentity(String address) {
    return _contract.onIdentityRegistered().asyncExpand((event) async* {
      final identity = await _contract.getIdentity(address);
      if (identity != null) yield identity;
    });
  }
}
