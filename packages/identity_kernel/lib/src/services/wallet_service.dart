import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/wallet.dart';
import '../repositories/wallet_repository_interface.dart';
import '../repositories/wallet_repository.dart';
import 'acki_nacki_client.dart';
import '../exceptions.dart';

class WalletService {
  final WalletRepository _repository;
  final AckiNackiClient? _chainClient;

  WalletService(this._repository, {AckiNackiClient? chainClient})
      : _chainClient = chainClient;

  Future<Wallet> initializeWallet(String identityId) async {
    final wallet = await _repository.generateWallet(identityId);

    if (_chainClient != null) {
      final walletData = await _repository.getWallet(identityId);
      if (walletData != null) {
        final identityRoot = sha256.convert(utf8.encode('dexchats_$identityId')).bytes;
        try {
          await _chainClient.registerIdentity(
            username: wallet.username,
            publicKey: _getPublicKey(identityId),
            privateKey: _getPrivateKey(identityId),
            identityRoot: identityRoot,
          );
        } catch (e) {
          throw WalletException('Failed to register wallet on chain: $e');
        }
      }
    }

    return wallet;
  }

  Future<Wallet> getWallet(String identityId) async {
    final wallet = await _repository.getWallet(identityId);
    if (wallet == null) {
      throw WalletException('Wallet not found for identity: $identityId');
    }
    return wallet;
  }

  Future<Map<String, int>> getBalances(String identityId) async {
    if (_chainClient != null) {
      final wallet = await getWallet(identityId);
      return _chainClient.getBalances(wallet.address);
    }
    final balanceJson = await _repository.getBalance(identityId);
    final decoded = jsonDecode(balanceJson) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, double.parse(v as String).toInt()));
  }

  Future<String> exportMnemonic(String identityId, String password) async {
    final isValid = await _repository.verifyPassword(identityId, password);
    if (!isValid) {
      throw WalletException('Invalid password');
    }
    return _repository.exportMnemonic(identityId);
  }

  Future<void> changeSeedPhrase(String identityId, String password) async {
    final isValid = await _repository.verifyPassword(identityId, password);
    if (!isValid) {
      throw WalletException('Invalid password');
    }
    await _repository.rotateSeedPhrase(identityId);

    if (_chainClient != null) {
      try {
        final newIdentityRoot = sha256.convert(utf8.encode('rotated_$identityId')).bytes;
        await _chainClient.rotateSeedPhrase(
          privateKey: _getPrivateKey(identityId),
          newIdentityRoot: newIdentityRoot,
        );
      } catch (e) {
        // Best-effort rotation
      }
    }
  }

  Future<String> signTransaction(String identityId, Map<String, dynamic> tx) async {
    final wallet = await _repository.getWallet(identityId);
    if (wallet == null) throw WalletException('Wallet not found');

    final txBytes = utf8.encode(jsonEncode(tx));
    return _repository.signChallenge(identityId, sha256.convert(txBytes).toString());
  }

  Future<void> postContent(String identityId, String contentHash) async {
    if (_chainClient == null) {
      throw WalletException('Chain client not available');
    }
    await _chainClient.postContentHash(
      privateKey: _getPrivateKey(identityId),
      contentHash: contentHash,
    );
  }

  Future<void> followUser(String identityId, String followeeAddress) async {
    if (_chainClient == null) {
      throw WalletException('Chain client not available');
    }
    await _chainClient.followUser(
      privateKey: _getPrivateKey(identityId),
      followeeAddress: followeeAddress,
    );
  }

  List<int> _getPublicKey(String identityId) {
    final repo = _repository;
    if (repo is MpcWalletRepository) {
      return repo.getPublicKey(identityId);
    }
    throw WalletException('Cannot access key material');
  }

  List<int> _getPrivateKey(String identityId) {
    final repo = _repository;
    if (repo is MpcWalletRepository) {
      return repo.getPrivateKey(identityId);
    }
    throw WalletException('Cannot access key material');
  }

  Future<void> initiateRecovery(String identityId) async {
    await _repository.initiateRecovery(identityId);
  }

  Future<bool> completeRecovery(String identityId, String confirmationCode) async {
    return _repository.completeRecovery(identityId, confirmationCode);
  }

  Stream<Wallet> watchWallet(String identityId) {
    return _repository.watchWallet(identityId);
  }
}
