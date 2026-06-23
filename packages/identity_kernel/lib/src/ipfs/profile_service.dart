import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/profile.dart';
import '../chain/an_identity_contract.dart';
import 'ipfs_client.dart';
import '../exceptions.dart';

/// Profile metadata stored on IPFS, CID committed on chain.
///
/// Every identity has an identityRoot on the AN chain that is the CID
/// of their IPFS profile JSON. This allows:
///   - Profile data fully owned by user (no server)
///   - Any field can be added without contract changes
///   - Profile history preserved (old versions still on IPFS)
class ProfileService {
  final AnIdentityContract _contract;
  final IpfsClient _ipfs;

  ProfileService({
    required AnIdentityContract contract,
    required IpfsClient ipfs,
  })  : _contract = contract,
        _ipfs = ipfs;

  /// Fetch profile from IPFS by identity. Falls back to on-chain data.
  Future<Profile> getProfile(String address) async {
    final identity = await _contract.getIdentity(address);
    if (identity == null) throw IdentityException('Identity not found: $address');

    // Try to fetch from IPFS first
    if (identity.identityCid != null) {
      try {
        final data = await _ipfs.fetchJson(identity.identityCid!);
        return Profile(
          displayName: data['displayName'] as String? ?? identity.profile.displayName,
          username: data['username'] as String? ?? identity.username.value,
          bio: data['bio'] as String? ?? '',
          avatarCid: data['avatarCid'] as String?,
          coverCid: data['coverCid'] as String?,
          joinedAt: identity.createdAt,
        );
      } catch (_) {
        // IPFS fetch failed; fall through to chain data
      }
    }

    return identity.profile;
  }

  /// Update profile: upload to IPFS, commit CID to chain.
  Future<String> updateProfile({
    required String identityAddress,
    required Profile profile,
    required List<int> signingKey,
  }) async {
    final profileJson = {
      'displayName': profile.displayName,
      'username': profile.username,
      'bio': profile.bio,
      'avatarCid': profile.avatarCid,
      'coverCid': profile.coverCid,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };

    final cid = await _ipfs.uploadJson(profileJson);

    final identityRoot = sha256.convert(utf8.encode(cid)).bytes;
    await _contract.updateIdentityRoot(identityAddress, identityRoot);

    return cid;
  }

  /// Get the IPFS gateway URL for a CID (for direct display).
  String? profileImageUrl(String? avatarCid) {
    if (avatarCid == null) return null;
    return _ipfs.gatewayUrl(avatarCid);
  }
}
