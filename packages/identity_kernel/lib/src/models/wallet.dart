import 'package:freezed_annotation/freezed_annotation.dart';

part 'wallet.freezed.dart';
part 'wallet.g.dart';

/// Acki Nacki Wallet — key material derived from passkey credential ID.
///
/// Keys are NEVER stored in plaintext. They are derived from:
///   SHA256("notjustdex_wallet_" + passkey_credential_id)
///
/// This means:
///   • Wallet is recoverable from passkey alone (passkey is backed up by OS)
///   • No seed phrase needed for normal operation
///   • Seed phrase export is available for cross-device recovery
@freezed
class Wallet with _$Wallet {
  const factory Wallet({
    required String address,
    required String username,

    /// Ed25519 public key bytes (32 bytes)
    @Default(<int>[]) List<int> publicKeyBytes,

    /// Ed25519 private key bytes (64 bytes) — ephemeral, for current session only
    @Default(<int>[]) List<int> privateKeyBytes,

    /// Device key share (stored in secure enclave)
    String? deviceShare,

    /// Cloud backup key share (encrypted)
    String? cloudShare,

    /// Recovery key share (derived from 24-word seed)
    String? recoveryShare,

    @Default(false) bool isInitialized,
    @Default(false) bool isRecovering,

    /// Seed phrase has been exported at least once
    @Default(false) bool seedPhraseExported,

    /// Current seed phrase version (increments on rotation)
    @Default(1) int seedVersion,

    /// Whether seed has been rotated (unique AN feature)
    @Default(false) bool seedRotated,

    @Default('') String recoveryId,

    /// Balances keyed by token symbol
    @Default({}) Map<String, String> balances,
  }) = _Wallet;

  factory Wallet.fromJson(Map<String, dynamic> json) =>
      _$WalletFromJson(json);
}
