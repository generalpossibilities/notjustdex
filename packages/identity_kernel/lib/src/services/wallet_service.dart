import 'dart:async';
import '../models/wallet.dart';
import '../repositories/wallet_repository.dart';
import '../exceptions.dart';

class WalletService {
  final WalletRepository _repository;

  WalletService(this._repository);

  Future<Wallet> initializeWallet(String identityId) async {
    final wallet = await _repository.generateWallet(identityId);
    return wallet;
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
  }

  Future<void> initiateRecovery(String identityId) async {
    await _repository.initiateRecovery(identityId);
  }

  Future<bool> completeRecovery(
    String identityId,
    String confirmationCode,
  ) async {
    return _repository.completeRecovery(identityId, confirmationCode);
  }

  Future<String> getBalance(String identityId) async {
    return _repository.getBalance(identityId);
  }

  Stream<Wallet> watchWallet(String identityId) {
    return _repository.watchWallet(identityId);
  }
}
