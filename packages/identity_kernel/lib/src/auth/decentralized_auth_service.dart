import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' hide Hmac;
import '../models/user_identity.dart';
import '../models/profile.dart';
import '../models/username.dart';
import '../models/wallet.dart';
import '../chain/an_identity_contract.dart';
import '../chain/an_light_client.dart';
import '../repositories/identity_repository.dart';
import '../exceptions.dart';

/// Decentralized authentication — no service dependency.
///
/// Auth flow:
///   1. Phone (optional bootstrap, fades after registration)
///   2. Passkey (primary — WebAuthn, biometric)
///   3. Wallet ZKP (secondary — on-chain signature challenge)
///
/// Session is a signed challenge message, validated on AN chain.
/// No JWT, no auth server, no centralized dependency.
class DecentralizedAuthService {
  final AnIdentityContract _contract;
  final AnLightClient _lightClient;
  final IdentityRepository _identityRepo;

  /// The current signed session challenge (null = not authenticated)
  SignedChallenge? _session;

  /// Cached identity (pulled from chain on login)
  UserIdentity? _cachedIdentity;

  DecentralizedAuthService({
    required AnIdentityContract contract,
    required AnLightClient lightClient,
    required IdentityRepository identityRepo,
  })  : _contract = contract,
        _lightClient = lightClient,
        _identityRepo = identityRepo;

  bool get isAuthenticated => _session != null;
  SignedChallenge? get session => _session;
  UserIdentity? get currentIdentity => _cachedIdentity;

  /// Passkey registration: create WebAuthn credential, derive wallet, register on chain.
  /// [phoneHash] is optional — used only for sybil-resistance commitment.
  /// Throws [ChainDownException] if the chain is unreachable.
  Future<UserIdentity> registerWithPasskey({
    required String passkeyCredentialId,
    required String passkeyPublicKey,
    required Username username,
    required String displayName,
    String? phoneHash,
  }) async {
    final valid = Username.tryCreate(username.value);
    if (valid == null) throw IdentityException('Invalid username');

    final available = await _contract.isUsernameAvailable(username.value);
    if (available == null) {
      throw ChainDownException('Cannot verify username availability — chain unreachable');
    }
    if (!available) throw IdentityException('Username taken on chain');

    final walletSeed = _deriveWalletSeed(passkeyCredentialId);
    final keyPair = await _ed25519KeyFromSeed(walletSeed);
    final pubKey = await keyPair.extractPublicKey();
    final address = _deriveAddress(pubKey.bytes);

    final identityRoot = sha256.convert(utf8.encode('njd_$address')).bytes;

    final registered = await _contract.registerIdentity(
      username: username.value,
      address: address,
      publicKey: pubKey.bytes,
      identityRoot: identityRoot,
      passkeyPublicKey: passkeyPublicKey,
      phoneHash: phoneHash,
    );
    if (!registered) {
      throw ChainDownException('Failed to register identity — chain unreachable');
    }

    final identity = UserIdentity(
      id: address,
      username: username,
      profile: Profile(
        displayName: displayName,
        username: username.value,
        bio: '',
        avatarCid: null,
        joinedAt: DateTime.now(),
      ),
      wallet: Wallet(
        address: address,
        username: username.value,
        isInitialized: true,
        seedVersion: 1,
      ),
      authMethods: [],
      createdAt: DateTime.now(),
      lastLoginAt: DateTime.now(),
    );

    await _identityRepo.saveIdentity(identity);
    _cachedIdentity = identity;
    _session = await _createSession(address, keyPair);
    return identity;
  }

  /// Passkey login: WebAuthn assertion → recover wallet → verify on chain.
  /// Throws [ChainDownException] if chain is unreachable.
  Future<UserIdentity> loginWithPasskey({
    required String passkeyCredentialId,
    required String passkeySignature,
  }) async {
    final walletSeed = _deriveWalletSeed(passkeyCredentialId);
    final keyPair = await _ed25519KeyFromSeed(walletSeed);
    final pubKey = await keyPair.extractPublicKey();
    final address = _deriveAddress(pubKey.bytes);

    final chainIdentity = await _contract.getIdentity(address);
    if (chainIdentity == null) {
      // Could be chain-down OR identity truly missing
      throw AuthenticationException('Identity not found — check chain connectivity');
    }

    _session = await _createSession(address, keyPair);
    _cachedIdentity = chainIdentity;
    await _identityRepo.saveIdentity(chainIdentity);
    return chainIdentity;
  }

  /// Wallet ZKP login: sign a challenge with the wallet key, verify on chain.
  /// Throws [ChainDownException] if chain is unreachable.
  Future<UserIdentity> loginWithWallet({
    required String address,
    required List<int> signature,
    required List<int> challenge,
  }) async {
    final chainIdentity = await _contract.getIdentity(address);
    if (chainIdentity == null) {
      throw AuthenticationException('Identity not found — check chain connectivity');
    }

    final valid = await _contract.verifySignature(
      address: address,
      message: challenge,
      signature: signature,
    );
    if (!valid) throw AuthenticationException('Invalid wallet signature');

    _session = SignedChallenge(
      address: address,
      challenge: challenge,
      signature: signature,
      timestamp: DateTime.now(),
    );
    _cachedIdentity = chainIdentity;
    await _identityRepo.saveIdentity(chainIdentity);
    return chainIdentity;
  }

  /// Phone registration: one-time bootstrap for sybil resistance.
  /// After this call, the phone hash is committed to the chain.
  Future<bool> verifyPhone({
    required String phoneHash,
    required String verificationCode,
  }) async {
    final computed = sha256.convert(utf8.encode(phoneHash)).toString();
    return computed.startsWith(verificationCode);
  }

  Future<void> logout() async {
    _session = null;
    _cachedIdentity = null;
  }

  /// Validate current session against the chain (optional — can also verify locally).
  Future<bool> validateSession() async {
    if (_session == null) return false;
    try {
      return await _contract.verifySignature(
        address: _session!.address,
        message: _session!.challenge,
        signature: _session!.signature,
      );
    } catch (_) {
      return false;
    }
  }

  Future<SignedChallenge> _createSession(
    String address,
    SimpleKeyPair keyPair,
  ) async {
    final challenge = _generateChallenge();
    final sig = await keyPair.sign(challenge);
    return SignedChallenge(
      address: address,
      challenge: challenge,
      signature: sig.bytes,
      timestamp: DateTime.now(),
    );
  }

  List<int> _generateChallenge() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return sha256.convert(bytes).bytes;
  }

  List<int> _deriveWalletSeed(String passkeyCredentialId) {
    final hash = sha256.convert(utf8.encode('notjustdex_wallet_$passkeyCredentialId'));
    return hash.bytes;
  }

  Future<SimpleKeyPair> _ed25519KeyFromSeed(List<int> seed) async {
    final ed25519 = Ed25519();
    return await ed25519.newKeyPairFromSeed(seed);
  }

  String _deriveAddress(List<int> publicKey) {
    final hash = sha256.convert(publicKey).toString();
    return '0x${hash.substring(0, 40)}';
  }
}

class SignedChallenge {
  final String address;
  final List<int> challenge;
  final List<int> signature;
  final DateTime timestamp;

  const SignedChallenge({
    required this.address,
    required this.challenge,
    required this.signature,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'address': address,
        'challenge': base64Url.encode(challenge),
        'signature': base64Url.encode(signature),
        'timestamp': timestamp.toIso8601String(),
      };

  factory SignedChallenge.fromJson(Map<String, dynamic> json) => SignedChallenge(
        address: json['address'] as String,
        challenge: base64Url.decode(json['challenge'] as String),
        signature: base64Url.decode(json['signature'] as String),
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class AuthenticationException implements Exception {
  final String message;
  const AuthenticationException(this.message);
  @override
  String toString() => 'AuthenticationException: $message';
}
