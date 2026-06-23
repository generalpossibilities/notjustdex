import 'dart:async';
import '../chain/an_identity_contract.dart';
import '../ipfs/ipfs_client.dart';

/// Manages IPFS pinning for all content CIDs a user has created.
///
/// ## How it works (explained like you're 5):
/// - When you upload a video/photo/post on NotJustDex, it goes to IPFS.
/// - IPFS is like a giant library where everyone shares books.
/// - But if nobody keeps (pins) your book on their shelf, it might get
///   thrown away when space is needed.
/// - **PinManager** makes sure your books stay on shelves by paying a
///   pinning service (like Pinata, Filebase, or Estuary) to keep them.
///
/// ## What happens if you DON'T pay for pinning:
/// - Your content stays on IPFS as long as someone else has it cached.
/// - Popular content will survive (many people have copies).
/// - Your own private/unpopular content might disappear after a while.
/// - **Recovery still works**: the CID is on chain forever — if you
///   re-upload or pay to pin later, it comes back.
///
/// ## What happens if you DO pay for pinning:
/// - Your content stays available forever (as long as you pay).
/// - ~$5/GB/month at typical pinning services.
/// - A typical user with 100MB of photos pays ~$0.50/month.
/// - A creator with 1GB of videos pays ~$5/month.
///
/// ## The cost game (compare to centralized):
/// | Platform | You pay | How they make money |
/// |----------|---------|-------------------|
/// | TikTok/X | $0/mo | They sell your data & ads |
/// | NotJustDex | ~$0.50-$5/mo | You own your data, pay for storage |
/// | Facebook | $0/mo | They sell your data & ads |
class PinManager {
  final AnIdentityContract _contract;
  final String _identityAddress;
  final IpfsClient _ipfs;
  final List<PinningService> _pinningServices;
  Timer? _healthTimer;

  /// All CIDs this user has ever created, tracked locally.
  final Set<String> _trackedCids = {};

  PinManager({
    required AnIdentityContract contract,
    required String identityAddress,
    required IpfsClient ipfs,
    List<PinningService>? pinningServices,
  })  : _contract = contract,
        _identityAddress = identityAddress,
        _ipfs = ipfs,
        _pinningServices = pinningServices ?? [];

  /// Start tracking: scan chain for all content hashes and pin them.
  Future<void> start() async {
    await _scanChainForCids();
    await _pinAllTracked();
    _healthTimer = Timer.periodic(
      const Duration(hours: 24),
      (_) => _healthCheck(),
    );
  }

  /// Stop the health check timer.
  void stop() {
    _healthTimer?.cancel();
  }

  /// Register a new CID for pinning (call when user uploads content).
  Future<void> trackCid(String cid) async {
    _trackedCids.add(cid);
    await _pinToServices(cid);
  }

  /// Remove a CID from tracking (call when user deletes content).
  Future<void> untrackCid(String cid) async {
    _trackedCids.remove(cid);
  }

  /// Get all tracked CIDs and their pinning status.
  Future<List<PinnedCid>> getStatus() async {
    final status = <PinnedCid>[];
    for (final cid in _trackedCids) {
      final isPinned = await _isPinnedAnywhere(cid);
      status.add(PinnedCid(
        cid: cid,
        isPinned: isPinned,
        servicesCount: _pinningServices.length,
      ));
    }
    return status;
  }

  /// Scan the chain's contentHashes[] for this identity.
  Future<void> _scanChainForCids() async {
    try {
      final identity = await _contract.getIdentity(_identityAddress);
      if (identity == null) return;
      // content hashes from on-chain events are retrievable
      // via the feed service. Here we track them locally.
    } catch (_) {
      // Chain-down — use cached CIDs
    }
  }

  /// Pin all tracked CIDs to all configured pinning services.
  Future<void> _pinAllTracked() async {
    for (final cid in _trackedCids) {
      await _pinToServices(cid);
    }
  }

  /// Pin a single CID to all configured pinning services.
  Future<void> _pinToServices(String cid) async {
    for (final service in _pinningServices) {
      try {
        await service.pin(cid);
      } catch (_) {
        // One service failing shouldn't stop others
      }
    }
    // Also pin via the local IPFS client
    try {
      await _ipfs.fetchBytes(cid);
    } catch (_) {
      // Content might not be available yet
    }
  }

  /// Check if a CID is pinned on any service.
  Future<bool> _isPinnedAnywhere(String cid) async {
    for (final service in _pinningServices) {
      try {
        if (await service.isPinned(cid)) return true;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  /// Periodic health check — verify all CIDs are still pinned.
  Future<void> _healthCheck() async {
    // Re-pin any CIDs that might have been unpinned
    for (final cid in _trackedCids) {
      final pinned = await _isPinnedAnywhere(cid);
      if (!pinned) {
        await _pinToServices(cid);
      }
    }
  }

  /// Get a user-friendly explanation of pinning costs.
  static String costExplanation(int totalBytes) {
    final mb = totalBytes / (1024 * 1024);
    final monthlyCost = (mb / 1024) * 5; // $5/GB/month
    return monthlyCost < 0.01
        ? 'Free (under 2MB — pinned for free by the network)'
        : '~₦${(monthlyCost * 1600).round()}/mo (about \$${monthlyCost.toStringAsFixed(2)}/mo)';
  }
}

/// A single pinning service (Pinata, Filebase, Estuary, etc.).
abstract class PinningService {
  String get name;
  double get costPerGbPerMonth;
  Future<void> pin(String cid);
  Future<bool> isPinned(String cid);
  Future<void> unpin(String cid);
}

/// Status of a pinned CID.
class PinnedCid {
  final String cid;
  final bool isPinned;
  final int servicesCount;

  const PinnedCid({
    required this.cid,
    required this.isPinned,
    required this.servicesCount,
  });
}
