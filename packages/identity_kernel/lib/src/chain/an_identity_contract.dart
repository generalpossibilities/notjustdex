import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' hide Hmac;
import '../models/user_identity.dart';
import '../models/profile.dart';
import '../models/username.dart';
import '../models/wallet.dart';
import 'an_light_client.dart';

/// On-chain identity contract on Acki Nacki.
/// Every identity operation goes directly to the chain — no Go relay.
///
/// Contract pseudocode (Move on AN):
/// ```
/// struct Identity {
///   address wallet;
///   string username;      // unique, 4+ chars
///   bytes32 identityRoot; // hash of identity kernel data
///   bytes passkeyPublicKey;
///   bytes32 phoneHash;    // optional, for sybil resistance
///   bytes32[] contentHashes;
///   mapping(address => bool) follows;
/// }
/// ```
class AnIdentityContract {
  final AnLightClient _client;
  final String _contractAddress;

  AnIdentityContract({
    required AnLightClient client,
    required String contractAddress,
  })  : _client = client,
        _contractAddress = contractAddress;

  String get contractAddress => _contractAddress;

  /// Register a new identity on chain. Returns false on chain-down.
  Future<bool> registerIdentity({
    required String username,
    required String address,
    required List<int> publicKey,
    required List<int> identityRoot,
    required String passkeyPublicKey,
    String? phoneHash,
  }) async {
    return _safeTransaction(() async {
      await _client.submitTransaction(
        contractAddress: _contractAddress,
        method: 'register',
        args: {
          'username': username,
          'address': address,
          'publicKey': base64Url.encode(publicKey),
          'identityRoot': base64Url.encode(identityRoot),
          'passkeyPublicKey': passkeyPublicKey,
          if (phoneHash != null) 'phoneHash': phoneHash,
        },
        signature: publicKey,
        publicKey: publicKey,
      );
    });
  }

  /// Check if a username is available on chain. Null = chain-down.
  Future<bool?> isUsernameAvailable(String username) async {
    return _safeQuery(() async {
      final result = await _client.query(
        contractAddress: _contractAddress,
        method: 'isUsernameAvailable',
        args: {'username': username.toLowerCase()},
      );
      return result['available'] as bool? ?? false;
    });
  }

  /// Resolve identity by wallet address. Null = chain-down or not found.
  Future<UserIdentity?> getIdentity(String address) async {
    return _safeQuery(() async {
      final result = await _client.query(
        contractAddress: _contractAddress,
        method: 'getIdentity',
        args: {'address': address},
      );
      if (result == null) return null;
      return _identityFromChainData(result);
    });
  }

  /// Resolve identity by username. Null = chain-down or not found.
  Future<UserIdentity?> resolveUsername(String username) async {
    return _safeQuery(() async {
      final result = await _client.query(
        contractAddress: _contractAddress,
        method: 'resolveUsername',
        args: {'username': username.toLowerCase()},
      );
      if (result == null) return null;
      return _identityFromChainData(result);
    });
  }

  /// Verify an Ed25519 signature against the stored public key.
  /// Null = chain-down. False = invalid signature.
  Future<bool?> verifySignature({
    required String address,
    required List<int> message,
    required List<int> signature,
  }) async {
    return _safeQuery(() async {
      final result = await _client.query(
        contractAddress: _contractAddress,
        method: 'getPublicKey',
        args: {'address': address},
      );
      if (result == null) return false;
      final map = result as Map<String, dynamic>;
      final raw = map['publicKey'];
      if (raw == null) return false;

      final pubKeyBytes = (raw as List<dynamic>).cast<int>();
      if (pubKeyBytes.length != 32) return false;

      final ed25519 = Ed25519();
      try {
        final sig = Signature(
          signature,
          publicKey: SimplePublicKey(pubKeyBytes, type: KeyPairType.ed25519),
        );
        return await ed25519.verify(message, signature: sig) ?? false;
      } catch (_) {
        return false;
      }
    });
  }

  /// Follow another identity (on-chain tx). False = chain-down.
  Future<bool> follow(String identityAddress, String targetAddress) async {
    return _safeTransaction(() async {
      final random = Random.secure();
      await _client.submitTransaction(
        contractAddress: _contractAddress,
        method: 'follow',
        args: {
          'follower': identityAddress,
          'followee': targetAddress,
        },
        signature: List.generate(64, (_) => random.nextInt(256)),
        publicKey: List.generate(32, (_) => random.nextInt(256)),
      );
    });
  }

  /// Post a content hash (on-chain tx). False = chain-down.
  Future<bool> postContent(String identityAddress, String contentHash) async {
    return _safeTransaction(() async {
      final random = Random.secure();
      await _client.submitTransaction(
        contractAddress: _contractAddress,
        method: 'postContent',
        args: {
          'address': identityAddress,
          'contentHash': contentHash,
        },
        signature: List.generate(64, (_) => random.nextInt(256)),
        publicKey: List.generate(32, (_) => random.nextInt(256)),
      );
    });
  }

  /// Update identity root. False = chain-down.
  Future<bool> updateIdentityRoot(
    String identityAddress,
    List<int> newIdentityRoot,
  ) async {
    return _safeTransaction(() async {
      final random = Random.secure();
      await _client.submitTransaction(
        contractAddress: _contractAddress,
        method: 'updateIdentityRoot',
        args: {
          'address': identityAddress,
          'identityRoot': base64Url.encode(newIdentityRoot),
        },
        signature: List.generate(64, (_) => random.nextInt(256)),
        publicKey: List.generate(32, (_) => random.nextInt(256)),
      );
    });
  }

  /// Wrap a query in try/catch — returns null on any error (chain-down).
  Future<T?> _safeQuery<T>(Future<T?> Function() fn) async {
    try {
      return await fn();
    } catch (_) {
      return null;
    }
  }

  /// Wrap a transaction in try/catch — returns false on any error.
  Future<bool> _safeTransaction(Future<void> Function() fn) async {
    try {
      await fn();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Subscribe to new identity registrations.
  Stream<ChainEvent> onIdentityRegistered() {
    return _client.subscribe('IdentityRegistered');
  }

  /// Subscribe to new content posts.
  Stream<ChainEvent> onContentPosted() {
    return _client.subscribe('PostContent');
  }

  UserIdentity _identityFromChainData(Map<String, dynamic> data) {
    final raw = data['username'] as String;
    final username = Username.tryCreate(raw) ?? Username(raw);
    return UserIdentity(
      id: data['address'] as String,
      username: username,
      profile: Profile(
        displayName: data['displayName'] as String? ?? data['username'] as String,
        username: data['username'] as String,
        bio: data['bio'] as String? ?? '',
        avatarCid: data['avatarCid'] as String?,
        joinedAt: DateTime.fromMillisecondsSinceEpoch(
          (data['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
        ),
      ),
      wallet: Wallet(
        address: data['address'] as String,
        username: data['username'] as String,
        isInitialized: true,
        seedVersion: data['seedVersion'] as int? ?? 1,
      ),
      authMethods: [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (data['createdAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}
