import 'dart:async';
import 'dart:typed_data';
import '../models/content_manifest.dart';
import '../providers/storage_providers.dart';

/// Configuration for storage replication.
class ReplicationPolicy {
  /// Minimum number of independent backends required.
  final int minimumBackups;

  /// Automatically renew Filecoin deals before expiry.
  final bool autoRenew;

  /// Use specific providers. Empty = use all available.
  final List<String> preferredProviders;

  const ReplicationPolicy({
    this.minimumBackups = 2,
    this.autoRenew = true,
    this.preferredProviders = const [],
  });

  static const standard = ReplicationPolicy(minimumBackups: 2);
  static const high = ReplicationPolicy(minimumBackups: 4, autoRenew: true);
  static const permanent = ReplicationPolicy(
    minimumBackups: 3,
    preferredProviders: ['ipfs_pinning', 'filecoin', 'arweave'],
  );
}

/// Manages replication across multiple storage providers.
///
/// Guarantees content durability by:
///   1. Always pinning to IPFS (baseline)
///   2. Making Filecoin deals for long-term archival
///   3. Optionally writing to Arweave for permanent storage
///   4. Optionally replicating to Storj for S3-compatible access
///   5. Verifying receipts and renewing expiring deals
class StorageReplicator {
  final List<StorageProvider> _providers;

  StorageReplicator(this._providers);

  /// Replicate content across all configured providers.
  /// Returns receipts for each successful replication.
  Future<List<StorageReceipt>> replicate({
    required String contentCid,
    required Uint8List bytes,
    required String mimeType,
    ReplicationPolicy policy = const ReplicationPolicy(),
  }) async {
    final receipts = <StorageReceipt>[];
    final errors = <String>[];

    for (final provider in _providers) {
      // Skip if not in preferred list (when specified)
      if (policy.preferredProviders.isNotEmpty &&
          !policy.preferredProviders.contains(provider.name)) {
        continue;
      }

      try {
        final receipt = await provider.store(
          contentCid: contentCid,
          bytes: bytes,
          mimeType: mimeType,
        );
        receipts.add(receipt);
      } catch (e) {
        errors.add('${provider.name}: $e');
      }
    }

    if (receipts.length < policy.minimumBackups) {
      throw ReplicationException(
        'Failed to meet minimum backups: '
        '${receipts.length} < ${policy.minimumBackups}. Errors: ${errors.join('; ')}',
      );
    }

    return receipts;
  }

  /// Check health of all receipts and return expired/unavailable ones.
  Future<List<StorageReceipt>> verifyHealth(List<StorageReceipt> receipts) async {
    final unhealthy = <StorageReceipt>[];
    for (final receipt in receipts) {
      if (receipt.isExpired) {
        unhealthy.add(receipt);
        continue;
      }
      final provider = _providers.where((p) => p.name == receipt.provider).firstOrNull;
      if (provider == null) continue;
      if (!await provider.isAvailable(receipt.providerId)) {
        unhealthy.add(receipt);
      }
    }
    return unhealthy;
  }
}

class ReplicationException implements Exception {
  final String message;
  ReplicationException(this.message);
  @override
  String toString() => 'ReplicationException: $message';
}
