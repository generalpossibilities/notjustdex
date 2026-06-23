import 'dart:convert';
import 'dart:math';
import 'package:bip39/bip39.dart' as bip39;
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' hide Hmac;
import '../models/wallet.dart';
import '../services/acki_nacki_client.dart';
import 'wallet_repository_interface.dart';
import '../exceptions.dart';

class MpcWalletRepository implements WalletRepository {
  final Map<String, _WalletData> _wallets = {};
  final Map<String, String> _passwords = {};
  final Random _random = Random.secure();
  final String? chainRpcUrl;

  MpcWalletRepository({this.chainRpcUrl});

  Future<Wallet> generateWallet(String identityId) async {
    final mnemonic = bip39.generateMnemonic(strength: 256);
    final seed = await bip39.mnemonicToSeed(mnemonic);
    final masterKey = seed;

    final shares = _splitKey(masterKey, totalShares: 3, threshold: 2);
    final keyPair = await _ed25519KeyFromSeed(masterKey);
    final pubKey = await keyPair.extractPublicKey();
    final address = deriveAddressFromPublicKey(pubKey.bytes);
    final privKeyBytes = await keyPair.extractPrivateKeyBytes();

    final walletData = _WalletData(
      address: address,
      username: identityId,
      mnemonic: mnemonic,
      deviceShare: shares[0],
      cloudShare: shares[1],
      recoveryShare: shares[2],
      publicKeyBytes: pubKey.bytes,
      privateKeyBytes: privKeyBytes,
      seedHash: sha256.convert(utf8.encode(mnemonic)).toString(),
    );

    _wallets[identityId] = walletData;
    return _toWallet(walletData);
  }

  Future<Wallet?> getWallet(String identityId) async {
    final data = _wallets[identityId];
    if (data == null) return null;
    return _toWallet(data);
  }

  Future<bool> verifyPassword(String identityId, String password) async {
    final hash = _passwords[identityId];
    if (hash == null) return false;

    final input = utf8.encode('notjustdex_pwd_$password');
    return sha256.convert(input).toString() == hash;
  }

  Future<String> exportMnemonic(String identityId) async {
    final data = _wallets[identityId];
    if (data == null) throw WalletException('Wallet not found');
    return data.mnemonic;
  }

  Future<void> rotateSeedPhrase(String identityId) async {
    final data = _wallets[identityId];
    if (data == null) throw WalletException('Wallet not found');

    final newMnemonic = bip39.generateMnemonic(strength: 256);
    final newSeed = await bip39.mnemonicToSeed(newMnemonic);
    final newShares = _splitKey(newSeed, totalShares: 3, threshold: 2);
    final newKeyPair = await _ed25519KeyFromSeed(newSeed);
    final newPubKey = await newKeyPair.extractPublicKey();
    final newAddress = deriveAddressFromPublicKey(newPubKey.bytes);
    final newPrivKey = await newKeyPair.extractPrivateKeyBytes();

    data.mnemonic = newMnemonic;
    data.address = newAddress;
    data.deviceShare = newShares[0];
    data.cloudShare = newShares[1];
    data.recoveryShare = newShares[2];
    data.publicKeyBytes = newPubKey.bytes;
    data.privateKeyBytes = newPrivKey;
    data.seedHash = sha256.convert(utf8.encode(newMnemonic)).toString();
    data.seedVersion += 1;
    data.seedRotated = true;
  }

  Future<void> initiateRecovery(String identityId) async {
    final data = _wallets[identityId];
    if (data == null) throw WalletException('Wallet not found');
    data.isRecovering = true;
    data.recoveryId = 'recovery_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<bool> completeRecovery(String identityId, String confirmationCode) async {
    final data = _wallets[identityId];
    if (data == null) throw WalletException('Wallet not found');
    if (!data.isRecovering) throw WalletException('No recovery in progress');

    if (confirmationCode.length >= 4) {
      data.isRecovering = false;
      return true;
    }
    return false;
  }

  Future<String> getBalance(String identityId) async {
    final data = _wallets[identityId];
    if (data == null) throw WalletException('Wallet not found');

    final random = Random(identityId.hashCode);
    final nackl = (random.nextDouble() * 10000).toStringAsFixed(4);
    final shell = (random.nextDouble() * 5000).toStringAsFixed(4);
    return '{"NACKL": "$nackl", "SHELL": "$shell"}';
  }

  Future<Map<String, int>> fetchChainBalances(String identityId) async {
    final data = _wallets[identityId];
    if (data == null) throw WalletException('Wallet not found');
    if (chainRpcUrl == null || chainRpcUrl!.isEmpty) {
      return {'NACKL': 0, 'SHELL': 0};
    }

    final client = AckiNackiClient(graphqlUrl: chainRpcUrl!);
    final balances = await client.getBalances(data.address);
    client.dispose();
    return balances;
  }

  Stream<Wallet> watchWallet(String identityId) {
    return Stream.periodic(const Duration(seconds: 30), (_) {
      final data = _wallets[identityId];
      if (data == null) throw WalletException('Wallet not found');
      return _toWallet(data);
    });
  }

  Future<String> signChallenge(String identityId, String challenge) async {
    final data = _wallets[identityId];
    if (data == null) throw WalletException('Wallet not found');

    final message = sha256.convert(utf8.encode(challenge)).bytes;
    final sig = await _ed25519Sign(message, data.privateKeyBytes);
    return base64Url.encode(sig);
  }

  Future<bool> verifyChallenge(String identityId, String challenge, String signature) async {
    final data = _wallets[identityId];
    if (data == null) return false;

    final message = sha256.convert(utf8.encode(challenge)).bytes;
    final sigBytes = base64Url.decode(signature);
    return await _ed25519Verify(message, sigBytes, data.publicKeyBytes);
  }

  List<String> _splitKey(List<int> secret, {required int totalShares, required int threshold}) {
    final shares = <String>[];
    final coefficients = <List<int>>[];
    final fieldSize = secret.length;

    for (var i = 1; i < threshold; i++) {
      coefficients.add(List.generate(fieldSize, (_) => _random.nextInt(256)));
    }

    for (var x = 1; x <= totalShares; x++) {
      final share = List<int>.from(secret);
      var xPow = x;
      for (final coeff in coefficients) {
        for (var j = 0; j < fieldSize; j++) {
          share[j] = (share[j] + coeff[j] * xPow) % 256;
        }
        xPow = (xPow * x) % 256;
      }
      shares.add(base64Url.encode(share));
    }

    return shares;
  }

  Future<SimpleKeyPair> _ed25519KeyFromSeed(List<int> seed) async {
    final ed25519 = Ed25519();
    final seedHash = sha256.convert(seed).bytes;
    return await ed25519.newKeyPairFromSeed(seedHash);
  }

  Future<List<int>> _ed25519Sign(List<int> message, List<int> privateKeyBytes) async {
    final ed25519 = Ed25519();
    final keyPair = SimpleKeyPair(
      SimpleKeyPairData(
        privateKey: privateKeyBytes,
        type: KeyPairType.ed25519,
      ),
    );
    final sig = await ed25519.sign(message, keyPair: keyPair);
    return sig.bytes;
  }

  Future<bool> _ed25519Verify(List<int> message, List<int> signature, List<int> publicKey) async {
    try {
      final ed25519 = Ed25519();
      final sig = Signature(signature, publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519));
      return await ed25519.verify(message, sig);
    } catch (_) {
      return false;
    }
  }

  List<int> getPublicKey(String identityId) {
    final data = _wallets[identityId];
    if (data == null) throw WalletException('Wallet not found');
    return List.from(data.publicKeyBytes);
  }

  List<int> getPrivateKey(String identityId) {
    final data = _wallets[identityId];
    if (data == null) throw WalletException('Wallet not found');
    return List.from(data.privateKeyBytes);
  }

  Wallet _toWallet(_WalletData data) => Wallet(
        address: data.address,
        username: data.username,
        deviceShare: data.deviceShare,
        cloudShare: data.cloudShare,
        recoveryShare: data.recoveryShare,
        isInitialized: true,
        isRecovering: data.isRecovering,
        seedPhraseExported: data.seedPhraseExported,
        seedVersion: data.seedVersion,
        seedRotated: data.seedRotated,
        recoveryId: data.recoveryId,
        balances: {},
      );
}

class _WalletData {
  String address;
  final String username;
  String mnemonic;
  String deviceShare;
  String cloudShare;
  String recoveryShare;
  String seedHash;
  int seedVersion = 1;
  bool isInitialized = true;
  bool isRecovering = false;
  bool seedPhraseExported = false;
  bool seedRotated = false;
  String recoveryId = '';
  List<int> publicKeyBytes;
  List<int> privateKeyBytes;

  _WalletData({
    required this.address,
    required this.username,
    required this.mnemonic,
    required this.deviceShare,
    required this.cloudShare,
    required this.recoveryShare,
    required this.seedHash,
    required this.publicKeyBytes,
    required this.privateKeyBytes,
  });
}
