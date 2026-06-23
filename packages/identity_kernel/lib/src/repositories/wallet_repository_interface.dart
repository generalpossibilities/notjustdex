import 'dart:async';
import '../models/wallet.dart';

abstract class WalletRepository {
  Future<Wallet> generateWallet(String identityId);
  Future<Wallet?> getWallet(String identityId);
  Future<bool> verifyPassword(String identityId, String password);
  Future<String> exportMnemonic(String identityId);
  Future<void> rotateSeedPhrase(String identityId);
  Future<void> initiateRecovery(String identityId);
  Future<bool> completeRecovery(String identityId, String confirmationCode);
  Future<String> getBalance(String identityId);
  Stream<Wallet> watchWallet(String identityId);
  Future<String> signChallenge(String identityId, String challenge);
  Future<bool> verifyChallenge(String identityId, String challenge, String signature);
  List<int> getPublicKey(String identityId);
  List<int> getPrivateKey(String identityId);
}
