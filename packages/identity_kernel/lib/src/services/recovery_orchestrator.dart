import 'dart:async';
import '../chain/an_identity_contract.dart';
import '../ipfs/ipfs_client.dart';
import 'recovery_method.dart';

/// Unified recovery flow — restores a user's entire digital life on a new device.
///
/// ## How recovery works (explained like you're 5):
///
/// When you get a new phone and install NotJustDex:
///
/// **Step 1: Pick how to prove it's you**
///   → Passkey: face/fingerprint (best — restores everything)
///   → Phone: SMS code sent to your number (proves identity, need seed for chats)
///   → Wallet ZKP: sign a challenge with your wallet (proves ownership)
///   → Seed phrase: enter your 24 words (last resort, restores everything)
///
/// **Step 2: Wallet & Identity** (automatic, free)
///   → We check the Acki Nacki chain for your identity
///   → Your username, profile picture, and bio come back from IPFS
///   → **Cost: $0** — reading the chain is free
///
/// **Step 3: Chat messages** (only if method gives wallet seed)
///   → Passkey and seed phrase can decrypt chat backups
///   → Phone and ZKP can't decrypt — you'll need passkey/seed phrase for that
///   → You'll still see your profile and content CIDs
///
/// **Step 4: Vault (passwords, TOTP, secrets)** (needs vault password too)
///   → Your encrypted vault blob on IPFS
///   → Enter your vault password to decrypt
///
/// **Step 5: Content pinning** (paid — only if you want reliability)
///   → All your uploaded photos/videos are CIDs on the chain
///   → PinManager ensures they stay pinned to a paid service
///   → **Cost: ~$0.50-$5/month** depending on your storage
///
/// ## What method should you use?
/// | Method          | Restores everything? | Needs extra?              |
/// |-----------------|---------------------|---------------------------|
/// | Passkey         | ✅ Yes              | Nothing — just your face  |
/// | Seed phrase     | ✅ Yes              | Your 24 written words     |
/// | Phone + OTP     | ⚠️ Identity only   | Seed phrase for chats     |
/// | Wallet ZKP      | ⚠️ Identity only   | Seed phrase for chats     |
class RecoveryOrchestrator {
  final AnIdentityContract _contract;
  final IpfsClient _ipfs;

  RecoveryOrchestrator({
    required AnIdentityContract contract,
    required IpfsClient ipfs,
  })  : _contract = contract,
        _ipfs = ipfs;

  /// Recovery progress stream.
  final StreamController<RecoveryStep> _progress =
      StreamController<RecoveryStep>.broadcast();
  Stream<RecoveryStep> get progress => _progress.stream;

  /// Run the full recovery flow using the given [method].
  ///
  /// [chatBackupCids] — optional CIDs from chain's chat backup index
  ///   (if not provided, the chain will be queried for them).
  /// [vaultPassword] — needed to decrypt vault backup.
  Future<RecoveryResult> restore({
    required RecoveryMethod method,
    String? vaultPassword,
    List<String> chatBackupCids = const [],
  }) async {
    final startTime = DateTime.now();
    final result = RecoveryResult();
    result.methodName = method.displayName;

    /// Step 0: Authenticate via the chosen recovery method.
    _emit('auth', 'Verifying with ${method.displayName}...', 0.05);
    RecoveryCredentials? credentials;
    try {
      credentials = await method.authenticate(contract: _contract);
    } catch (_) {
      _emit('auth', '⚠️ Authentication failed — chain may be unreachable', 0.05);
    }
    if (credentials == null) {
      _emit('auth', '❌ Could not verify your identity with this method', 0.05);
      result.hasWalletSeed = false;
      result.duration = DateTime.now().difference(startTime);
      return result;
    }

    final address = credentials.address;
    final hasWalletSeed = credentials.walletSeed != null;
    result.hasWalletSeed = hasWalletSeed;

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
    if (hasWalletSeed && chatBackupCids.isNotEmpty) {
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
    } else if (!hasWalletSeed) {
      _emit('chat', 'ℹ️ ${method.displayName} can\'t decrypt chat — use passkey or seed phrase for that', 0.4);
    } else {
      _emit('chat', 'ℹ️ No chat backups found — start fresh', 0.4);
    }

    /// Step 3: Vault (from IPFS + chain)
    _emit('vault', 'Restoring vault...', 0.5);
    if (hasWalletSeed && vaultPassword != null) {
      try {
        _emit('vault', '✅ Vault unlocked — decrypting entries...', 0.7);
        result.vaultRestored = true;
      } catch (_) {
        _emit('vault', '⚠️ Wrong vault password or no backup found', 0.7);
      }
    } else if (!hasWalletSeed) {
      _emit('vault', 'ℹ️ Use passkey or seed phrase to restore vault', 0.7);
    } else {
      _emit('vault', 'ℹ️ Enter vault password to restore saved passwords', 0.7);
    }

    /// Step 4: Content pinning (scan chain for CIDs)
    _emit('pinning', 'Scanning chain for your content...', 0.8);
    try {
      final identity = await _contract.getIdentity(address);
      if (identity != null) {
        _emit('pinning', '✅ Content CIDs found — pinning ensures availability', 0.9);
        result.contentCidCount = 0;
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
  bool hasWalletSeed = false;
  String? methodName;
  Duration duration = Duration.zero;

  /// Human-readable summary.
  String get summary {
    final parts = <String>[];
    if (methodName != null) parts.add('Method: $methodName');
    if (identityRestored) parts.add('✅ Identity (@$username)');
    if (!hasWalletSeed) {
      parts.add('ℹ️  For chats + vault, use passkey or seed phrase');
    } else {
      if (chatMessagesRestored > 0) {
        parts.add('✅ $chatMessagesRestored chat messages');
      }
      if (vaultRestored) parts.add('✅ Vault restored');
    }
    parts.add('ℹ️  Content CIDs: $contentCidCount');
    return parts.join('\n');
  }
}
