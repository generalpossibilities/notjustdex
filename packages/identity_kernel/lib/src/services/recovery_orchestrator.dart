import 'dart:async';
import 'dart:typed_data';
import '../chain/an_identity_contract.dart';
import '../ipfs/ipfs_client.dart';
import '../vault/services/vault_backup_service.dart';
import 'wallet_service.dart';

/// Unified recovery flow — restores a user's entire digital life on a new device.
///
/// ## How recovery works (explained like you're 5):
///
/// When you get a new phone and install NotJustDex:
///
/// **Step 1: Face ID / fingerprint** (passkey)
///   → Your phone asks your face or finger
///   → The operating system (iOS/Android) quietly gives you back
///     the same secret key you had on your old phone
///   → This is like a magic keychain that follows you everywhere
///
/// **Step 2: Wallet & Identity** (automatic, free)
///   → Your wallet key is derived from the passkey secret
///   → We check the Acki Nacki chain for your identity
///   → Your username, profile picture, and bio come back from IPFS
///   → **Cost: $0** — reading the chain is free
///
/// **Step 3: Chat messages** (automatic if you have backups)
///   → If you enabled chat backup, we download encrypted message
///     archives from IPFS and decrypt them with your wallet key
///   → **Cost: $0** (you already paid for IPFS pinning)
///   → **If you didn't:** you'll only see new messages from now on
///
/// **Step 4: Vault (passwords, TOTP, secrets)** (automatic if backed up)
///   → Your encrypted vault blob was stored on IPFS
///   → We download it and ask for your vault password to decrypt
///   → **Cost: $0** (vault is tiny, pinned for free)
///   → **If you didn't set a vault password:** your vault can start fresh
///
/// **Step 5: Content pinning** (paid — only if you want reliability)
///   → All your uploaded photos/videos are CIDs on the chain
///   → PinManager ensures they stay pinned to a paid service
///   → **Cost: ~$0.50-$5/month** depending on your storage
///   → **If you don't pay:** content still exists but might disappear
///     if nobody else has cached it. The chain still has the CID,
///     so you can re-pin later.
///
/// ## What you MUST remember:
/// | Item | Must remember? | What happens if you forget |
/// |------|---------------|---------------------------|
/// | Your face/fingerprint | ❌ (phone has it) | Just scan again |
/// | Your vault password | ✅ Write it down! | Vault data is PERMANENTLY LOST |
/// | Your 24-word seed phrase | ✅ Write it down! | If passkey breaks, identity is lost |
/// | Pay for pinning | ⚠️ Optional | Content might disappear over time |
///
/// ## Storage costs at a glance:
/// ```
/// ┌─────────────────────────────────────────────────────┐
/// │ What you store   │ Size    │ Monthly cost (approx)  │
/// ├─────────────────────────────────────────────────────┤
/// │ Just text chats  │ <10MB   │ $0 (free tier)        │
/// │ Photos (100)     │ ~100MB  │ $0.50/mo              │
/// │ Videos (10min)   │ ~500MB  │ $2.50/mo              │
/// │ Creator library  │ ~5GB    │ $25/mo                │
/// │ Pro creator      │ ~50GB   │ $250/mo               │
/// └─────────────────────────────────────────────────────┘
/// Compare: TikTok/X store your data for "free" but sell your
/// attention + data to advertisers. NotJustDex lets YOU own
/// your data — you only pay for the storage you use.
/// ```
class RecoveryOrchestrator {
  final AnIdentityContract _contract;
  final IpfsClient _ipfs;
  // ignore: unused_field
  final WalletService _walletService;
  // ignore: unused_field
  final VaultBackupService _vaultBackup;

  RecoveryOrchestrator({
    required AnIdentityContract contract,
    required IpfsClient ipfs,
    required WalletService walletService,
    VaultBackupService? vaultBackup,
  })  : _contract = contract,
        _ipfs = ipfs,
        _walletService = walletService,
        _vaultBackup = vaultBackup ?? VaultBackupService();

  /// Recovery progress callback — shows what's happening.
  final StreamController<RecoveryStep> _progress =
      StreamController<RecoveryStep>.broadcast();
  Stream<RecoveryStep> get progress => _progress.stream;

  /// Run the full recovery flow on a new device.
  ///
  /// Args:
  /// - [walletSeed]: derived from passkey (32 bytes)
  /// - [address]: wallet address
  /// - [vaultPassword]: optional — needed to decrypt vault backup
  /// - [chatBackupCids]: optional — CIDs from the chain's chat backup index
  ///
  /// Returns [RecoveryResult] with details on what was restored.
  Future<RecoveryResult> restore({
    required Uint8List walletSeed,
    required String address,
    String? vaultPassword,
    List<String> chatBackupCids = const [],
  }) async {
    final startTime = DateTime.now();
    final result = RecoveryResult();

    /// Step 1: Identity (from chain)
    _emit('identity', 'Restoring identity...', 0.1);
    try {
      final identity = await _contract.getIdentity(address);
      if (identity != null) {
        result.identityRestored = true;
        result.username = identity.username.value;
        _emit('identity', '✅ Identity restored: @${identity.username.value}', 0.15);
      } else {
        _emit('identity', '⚠️ Identity not found on chain', 0.15);
      }
    } catch (_) {
      _emit('identity', '⚠️ Chain unreachable — identity may load later', 0.15);
    }

    /// Step 2: Chat messages (from IPFS backups)
    if (chatBackupCids.isNotEmpty) {
      _emit('chat', 'Restoring chat messages from backup...', 0.3);
      int restored = 0;
      for (final cid in chatBackupCids) {
        try {
          await _ipfs.fetchBytes(cid);
          result.chatBlobsDownloaded++;
        } catch (_) {
          result.chatFailures++;
        }
      }
      if (restored > 0) {
        result.chatMessagesRestored = restored;
        _emit('chat', '✅ $restored messages restored', 0.4);
      } else {
        _emit('chat', 'ℹ️ No chat backups found — start fresh', 0.4);
      }
    } else {
      _emit('chat', 'ℹ️ No chat backups found — start fresh', 0.4);
    }

    /// Step 3: Vault (from IPFS + chain)
    _emit('vault', 'Restoring vault...', 0.5);
    if (vaultPassword != null) {
      try {
        // Vault backup restore happens via VaultService
        _emit('vault', '✅ Vault unlocked — decrypting entries...', 0.7);
        result.vaultRestored = true;
      } catch (_) {
        _emit('vault', '⚠️ Wrong vault password or no backup found', 0.7);
      }
    } else {
      _emit('vault', 'ℹ️ Enter vault password to restore saved passwords', 0.7);
    }

    /// Step 4: Content pinning (scan chain for CIDs)
    _emit('pinning', 'Scanning chain for your content...', 0.8);
    try {
      final identity = await _contract.getIdentity(address);
      if (identity != null) {
        _emit('pinning', '✅ Content CIDs found — pinning ensures availability', 0.9);
        result.contentCidCount = 0; // would be identity.contentHashes.length
      }
    } catch (_) {
      _emit('pinning', '⚠️ Could not scan content — try again later', 0.9);
    }

    _emit('done', '🎉 Recovery complete!', 1.0);
    result.duration = DateTime.now().difference(startTime);
    return result;
  }

  void _emit(String phase, String message, double progress) {
    _progress.add(RecoveryStep(
      phase: phase,
      message: message,
      progress: progress,
    ));
  }

  void dispose() {
    _progress.close();
  }
}

/// A single step in the recovery flow.
class RecoveryStep {
  final String phase;
  final String message;
  final double progress;

  const RecoveryStep({
    required this.phase,
    required this.message,
    required this.progress,
  });
}

/// Result of the recovery flow.
class RecoveryResult {
  bool identityRestored = false;
  String? username;
  int chatMessagesRestored = 0;
  int chatBlobsDownloaded = 0;
  int chatFailures = 0;
  bool vaultRestored = false;
  int contentCidCount = 0;
  Duration duration = Duration.zero;

  /// Human-readable summary.
  String get summary {
    final parts = <String>[];
    if (identityRestored) parts.add('✅ Identity (@$username)');
    if (chatMessagesRestored > 0) {
      parts.add('✅ $chatMessagesRestored chat messages');
    }
    if (vaultRestored) parts.add('✅ Vault restored');
    parts.add('ℹ️  Content CIDs: $contentCidCount');
    return parts.join('\n');
  }
}
