import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' show sha256, Hmac;
import 'package:cryptography/cryptography.dart' hide Hmac;
import '../chain/an_identity_contract.dart';
import '../models/user_identity.dart';

/// Credentials resolved by a recovery method.
///
/// At minimum we need the [address] to look up identity data on chain.
/// [walletSeed] is only available from methods that derive the wallet key
/// (passkey or seed phrase) — it's needed to decrypt private data like
/// chats and vault entries. Phone and ZKP methods can only provide the
/// address; encrypted data recovery requires an additional step.
class RecoveryCredentials {
  final String address;
  final Uint8List? walletSeed;
  final String? vaultPassword;

  const RecoveryCredentials({
    required this.address,
    this.walletSeed,
    this.vaultPassword,
  });
}

/// Pluggable recovery method. Each method authenticates the user in a
/// fully decentralized way and resolves their on-chain identity address.
///
/// New methods can be added without changing [RecoveryOrchestrator]:
/// just implement this interface and pass it to [RecoveryOrchestrator.restore].
abstract class RecoveryMethod {
  String get displayName;
  String get iconName;

  /// Authenticate the user and resolve their wallet address.
  /// Returns null if authentication fails or chain is unreachable.
  Future<RecoveryCredentials?> authenticate({
    required AnIdentityContract contract,
  });
}

/// ---------------------------------------------------------------------------
/// 1. Passkey Recovery — biometric, primary method
/// ---------------------------------------------------------------------------
///
/// Derives wallet seed from the WebAuthn credential ID (same as login).
/// Full recovery: identity + encrypted data.
class PasskeyRecoveryMethod implements RecoveryMethod {
  final String passkeyCredentialId;

  PasskeyRecoveryMethod(this.passkeyCredentialId);

  @override
  String get displayName => 'Passkey (Face ID / fingerprint)';
  @override
  String get iconName => 'fingerprint';

  @override
  Future<RecoveryCredentials?> authenticate({
    required AnIdentityContract contract,
  }) async {
    final walletSeed = _deriveWalletSeed(passkeyCredentialId);
    final keyPair = await _ed25519FromSeed(walletSeed);
    final pubKey = await keyPair.extractPublicKey();
    final address = _deriveAddress(pubKey.bytes);

    final identity = await contract.getIdentity(address);
    if (identity == null) return null;

    return RecoveryCredentials(
      address: address,
      walletSeed: Uint8List.fromList(walletSeed),
    );
  }

  static List<int> _deriveWalletSeed(String credentialId) {
    return sha256
        .convert(utf8.encode('notjustdex_wallet_$credentialId'))
        .bytes;
  }

  static Future<SimpleKeyPair> _ed25519FromSeed(List<int> seed) async {
    return Ed25519().newKeyPairFromSeed(seed);
  }

  static String _deriveAddress(List<int> publicKey) {
    final hash = sha256.convert(publicKey).toString();
    return '0x${hash.substring(0, 40)}';
  }
}

/// ---------------------------------------------------------------------------
/// 2. Phone OTP Recovery — one-time code to your international number
/// ---------------------------------------------------------------------------
///
/// How it works (fully decentralized):
///   1. You enter your phone number + the OTP code sent to it
///   2. The app hashes your phone and looks up the matching identity on chain
///      (the phone hash was committed during registration)
///   3. Your identity address is resolved → recovery can begin
///
/// Limitations:
///   - Phone-Otp alone CANNOT decrypt chat/vault data (no wallet seed)
///   - After phone recovery you'll need your passkey or seed phrase
///     to restore encrypted data
///   - This is fine — the phone is proof of identity, not a crypto key
class PhoneRecoveryMethod implements RecoveryMethod {
  final String e164Phone;
  final String otpCode;

  PhoneRecoveryMethod({
    required this.e164Phone,
    required this.otpCode,
  });

  @override
  String get displayName => 'Phone Verification (SMS code)';
  @override
  String get iconName => 'phone_android';

  @override
  Future<RecoveryCredentials?> authenticate({
    required AnIdentityContract contract,
  }) async {
    final phoneHash = _computePhoneHash(e164Phone);

    final valid = _verifyOtp(phoneHash, otpCode);
    if (!valid) return null;

    final identity = await contract.resolveByPhoneHash(phoneHash);
    if (identity == null) return null;

    return RecoveryCredentials(address: identity.id);
  }

  /// Phone hash = SHA-256 of the E.164 phone number.
  /// This is committed to the chain during registration and used
  /// as a sybil-resistance mechanism. Only the hash is stored —
  /// the raw phone number never touches a server.
  static String _computePhoneHash(String e164) {
    return sha256.convert(utf8.encode(e164)).toString();
  }

  /// OTP verification: the code must match the first 6 hex chars
  /// of a double SHA-256 of the phone hash. This is a simplified
  /// proof-of-concept — production would use time-based tokens.
  static bool _verifyOtp(String phoneHash, String code) {
    final doubleHash = sha256.convert(utf8.encode(phoneHash)).toString();
    return doubleHash.startsWith(code.toLowerCase());
  }
}

/// ---------------------------------------------------------------------------
/// 3. Wallet ZKP Recovery — zero-knowledge proof of wallet ownership
/// ---------------------------------------------------------------------------
///
/// If you have your wallet connected to the device (e.g., browser
/// extension, hardware wallet, or another app instance), you can prove
/// ownership by signing a challenge — no seed phrase needed.
///
/// The signature is verified on the Acki Nacki chain against the
/// Ed25519 public key stored at registration.
///
/// Limitations:
///   - Zkp alone CANNOT decrypt chat/vault data (no wallet seed)
///   - It proves you own the wallet, but the wallet seed is embedded
///     in the passkey, not extractable from a signature alone
class WalletZkpRecoveryMethod implements RecoveryMethod {
  final String address;
  final List<int> challenge;
  final List<int> signature;

  WalletZkpRecoveryMethod({
    required this.address,
    required this.challenge,
    required this.signature,
  });

  @override
  String get displayName => 'Wallet ZKP (signature proof)';
  @override
  String get iconName => 'verified_user';

  @override
  Future<RecoveryCredentials?> authenticate({
    required AnIdentityContract contract,
  }) async {
    final valid = await contract.verifySignature(
      address: address,
      message: challenge,
      signature: signature,
    );
    if (valid != true) return null;

    return RecoveryCredentials(address: address);
  }
}

/// ---------------------------------------------------------------------------
/// 4. Seed Phrase Recovery — 24-word mnemonic
/// ---------------------------------------------------------------------------
///
/// Full recovery: the seed phrase re-derives the wallet key, giving
/// access to both the identity AND all encrypted data.
///
/// This is the last resort if passkey is unavailable.
class SeedPhraseRecoveryMethod implements RecoveryMethod {
  final String mnemonic;

  SeedPhraseRecoveryMethod(this.mnemonic);

  @override
  String get displayName => '24-Word Recovery Phrase';
  @override
  String get iconName => 'key';

  @override
  Future<RecoveryCredentials?> authenticate({
    required AnIdentityContract contract,
  }) async {
    final words = mnemonic
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'));
    if (words.length != 24) return null;

    final walletSeed = _mnemonicToSeed(words);
    final keyPair = await _ed25519FromSeed(walletSeed);
    final pubKey = await keyPair.extractPublicKey();
    final address = _deriveAddress(pubKey.bytes);

    final identity = await contract.getIdentity(address);
    if (identity == null) return null;

    return RecoveryCredentials(
      address: address,
      walletSeed: Uint8List.fromList(walletSeed),
    );
  }

  /// Convert 24 BIP39-like words to a 32-byte seed.
  /// Uses a simplified derivation: HMAC-SHA256 with key "notjustdex_seed"
  /// over the space-joined words. Production would use proper BIP39.
  static List<int> _mnemonicToSeed(List<String> words) {
    final phrase = words.join(' ');
    final hmac = Hmac(sha256, utf8.encode('notjustdex_seed'));
    return hmac.convert(utf8.encode(phrase)).bytes;
  }

  static Future<SimpleKeyPair> _ed25519FromSeed(List<int> seed) async {
    return Ed25519().newKeyPairFromSeed(seed);
  }

  static String _deriveAddress(List<int> publicKey) {
    final hash = sha256.convert(publicKey).toString();
    return '0x${hash.substring(0, 40)}';
  }
}
