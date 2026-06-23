import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' hide Hmac;
import '../models/wallet.dart';
import '../repositories/wallet_repository_interface.dart';
import '../exceptions.dart';

/// Wallet service — keys derived from passkey credential ID.
///
/// No Go service, no centralized key server.
/// Wallet seed = SHA256("notjustdex_wallet_" + passkey_credential_id)
/// This makes the wallet fully recoverable from the passkey alone.
class WalletService {
  final WalletRepository _repository;

  WalletService(this._repository);

  /// Initialize wallet from a passkey credential ID.
  /// The wallet keys are derived deterministically from the credential ID.
  Future<Wallet> initializeWallet(String identityId, String passkeyCredentialId) async {
    final wallet = await _repository.generateWallet(identityId);

    final seed = _deriveSeed(passkeyCredentialId);
    final keyPair = await _ed25519FromSeed(seed);
    final pubKey = await keyPair.extractPublicKey();
    final privKeyBytes = await keyPair.extractPrivateKeyBytes();
    final address = _deriveAddress(pubKey.bytes);

    final updated = wallet.copyWith(
      address: address,
      publicKeyBytes: pubKey.bytes.toList(),
      privateKeyBytes: privKeyBytes.toList(),
      isInitialized: true,
    );

    return updated;
  }

  /// Recover wallet from passkey credential ID (login).
  Future<Wallet> recoverWallet(String passkeyCredentialId) async {
    final seed = _deriveSeed(passkeyCredentialId);
    final keyPair = await _ed25519FromSeed(seed);
    final pubKey = await keyPair.extractPublicKey();
    final privKeyBytes = await keyPair.extractPrivateKeyBytes();
    final address = _deriveAddress(pubKey.bytes);

    return Wallet(
      address: address,
      username: '',
      publicKeyBytes: pubKey.bytes.toList(),
      privateKeyBytes: privKeyBytes.toList(),
      isInitialized: true,
      seedVersion: 1,
    );
  }

  /// Sign a challenge with the wallet key.
  Future<List<int>> signChallenge(String identityId, List<int> challenge) async {
    final privKey = await _repository.getPrivateKey(identityId);
    final ed25519 = Ed25519();
    final keyPair = await ed25519.newKeyPairFromSeed(privKey);
    final sig = await ed25519.sign(challenge, keyPair: keyPair);
    return sig.bytes.toList();
  }

  Future<Wallet> getWallet(String identityId) async {
    final wallet = await _repository.getWallet(identityId);
    if (wallet == null) {
      throw WalletException('Wallet not found for identity: $identityId');
    }
    return wallet;
  }

  Future<String> exportMnemonic(String identityId, String password) async {
    final isValid = await _repository.verifyPassword(identityId, password);
    if (!isValid) throw WalletException('Invalid password');
    return _repository.exportMnemonic(identityId);
  }

  Future<void> changeSeedPhrase(String identityId, String password) async {
    final isValid = await _repository.verifyPassword(identityId, password);
    if (!isValid) throw WalletException('Invalid password');
    await _repository.rotateSeedPhrase(identityId);
  }

  List<int> _deriveSeed(String passkeyCredentialId) {
    return sha256.convert(utf8.encode('notjustdex_wallet_$passkeyCredentialId')).bytes;
  }

  Future<SimpleKeyPair> _ed25519FromSeed(List<int> seed) async {
    final ed25519 = Ed25519();
    return await ed25519.newKeyPairFromSeed(seed);
  }

  String _deriveAddress(List<int> publicKey) {
    final hash = sha256.convert(publicKey).toString();
    return '0x${hash.substring(0, 40)}';
  }
}
