import 'dart:convert';
import 'dart:typed_data';

/// Content manifest — the root of all content addressing.
///
/// Every piece of content (video, image, audio, text) has one manifest.
/// The manifest CID is committed on the AN chain, making it immutable and
/// permanently discoverable.
///
/// A manifest can reference:
///   - Raw media CID (single image/audio/text file)
///   - HLS playlist CID + segment CIDs (for video)
///   - Thumbnail CID
///   - Multiple storage provider proofs (Filecoin deal IDs, Arweave tx IDs)
class ContentManifest {
  /// Version of the manifest format.
  final int version;

  /// When this content was created.
  final DateTime createdAt;

  /// Content type: video, image, audio, text, document
  final String contentType;

  /// MIME type (e.g. video/mp4, image/jpeg)
  final String mimeType;

  /// Original filename before upload.
  final String? originalFilename;

  /// Size in bytes of the original content.
  final int? originalSize;

  /// Single media CID (for images, audio, small files).
  final String? mediaCid;

  /// HLS video manifest CID (for video content).
  final String? hlsPlaylistCid;

  /// Ordered list of HLS segment CIDs.
  final List<String>? hlsSegmentCids;

  /// Thumbnail / preview image CIDs.
  final List<String>? thumbnailCids;

  /// Alternative resolutions (e.g. {'720p': '<hls_playlist_cid>'})
  final Map<String, String>? variants;

  /// Storage receipts — proofs of replication on each backend.
  final List<StorageReceipt> storageReceipts;

  /// Custom metadata (tags, description, etc.)
  final Map<String, dynamic> metadata;

  const ContentManifest({
    this.version = 1,
    required this.createdAt,
    required this.contentType,
    required this.mimeType,
    this.originalFilename,
    this.originalSize,
    this.mediaCid,
    this.hlsPlaylistCid,
    this.hlsSegmentCids,
    this.thumbnailCids,
    this.variants,
    this.storageReceipts = const [],
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'created_at': createdAt.toIso8601String(),
    'content_type': contentType,
    'mime_type': mimeType,
    'original_filename': originalFilename,
    'original_size': originalSize,
    'media_cid': mediaCid,
    'hls_playlist_cid': hlsPlaylistCid,
    'hls_segment_cids': hlsSegmentCids,
    'thumbnail_cids': thumbnailCids,
    'variants': variants,
    'storage_receipts': storageReceipts.map((r) => r.toJson()).toList(),
    'metadata': metadata,
  };

  factory ContentManifest.fromJson(Map<String, dynamic> json) => ContentManifest(
    version: json['version'] as int? ?? 1,
    createdAt: DateTime.parse(json['created_at'] as String),
    contentType: json['content_type'] as String,
    mimeType: json['mime_type'] as String,
    originalFilename: json['original_filename'] as String?,
    originalSize: json['original_size'] as int?,
    mediaCid: json['media_cid'] as String?,
    hlsPlaylistCid: json['hls_playlist_cid'] as String?,
    hlsSegmentCids: (json['hls_segment_cids'] as List?)?.cast<String>(),
    thumbnailCids: (json['thumbnail_cids'] as List?)?.cast<String>(),
    variants: (json['variants'] as Map<String, dynamic>?)
        ?.map((k, v) => MapEntry(k, v as String)),
    storageReceipts: (json['storage_receipts'] as List?)
            ?.map((e) => StorageReceipt.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
  );
}

/// Proof that content is stored on a specific backend.
///
/// Multiple receipts across different providers = redundancy.
/// Content is not lost as long as at least one receipt is valid.
class StorageReceipt {
  /// Provider name: 'ipfs', 'filecoin', 'arweave', 'storj', 'pinata', etc.
  final String provider;

  /// Provider-specific identifier (deal ID, tx hash, object key, etc.)
  final String providerId;

  /// When the storage was deposited.
  final DateTime depositedAt;

  /// When the storage expires (null = permanent).
  final DateTime? expiresAt;

  /// Whether the storage has been verified (e.g. Filecoin deal proven).
  final bool verified;

  /// Cost paid (in USD cents, or token amount).
  final int? costPaid;

  /// Currency of cost (e.g. 'usd', 'fil', 'ar', 'storj')
  final String? costCurrency;

  const StorageReceipt({
    required this.provider,
    required this.providerId,
    required this.depositedAt,
    this.expiresAt,
    this.verified = false,
    this.costPaid,
    this.costCurrency,
  });

  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'provider_id': providerId,
    'deposited_at': depositedAt.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
    'verified': verified,
    'cost_paid': costPaid,
    'cost_currency': costCurrency,
  };

  factory StorageReceipt.fromJson(Map<String, dynamic> json) => StorageReceipt(
    provider: json['provider'] as String,
    providerId: json['provider_id'] as String,
    depositedAt: DateTime.parse(json['deposited_at'] as String),
    expiresAt: json['expires_at'] != null
        ? DateTime.parse(json['expires_at'] as String)
        : null,
    verified: json['verified'] as bool? ?? false,
    costPaid: json['cost_paid'] as int?,
    costCurrency: json['cost_currency'] as String?,
  );
}

/// Available storage providers with configuration.
class StorageProviderConfig {
  final String name;

  /// Cost per GB per month in USD cents (0 = free).
  final int costPerGbMonth;

  /// Whether content expires.
  final bool hasExpiry;

  /// Maximum file size in bytes (null = unlimited).
  final int? maxFileSize;

  /// Supported content types (empty = all).
  final List<String> supportedTypes;

  const StorageProviderConfig({
    required this.name,
    this.costPerGbMonth = 0,
    this.hasExpiry = true,
    this.maxFileSize,
    this.supportedTypes = const [],
  });

  static const ipfsPinning = StorageProviderConfig(
    name: 'ipfs_pinning',
    costPerGbMonth: 5,  // ~$5/GB/month for commercial pinning
    hasExpiry: true,
  );

  static const filecoin = StorageProviderConfig(
    name: 'filecoin',
    costPerGbMonth: 0,  // ~$0.01/GB/year via verified deals
    hasExpiry: true,
    maxFileSize: 32 << 30,  // 32GB typical sector
  );

  static const arweave = StorageProviderConfig(
    name: 'arweave',
    costPerGbMonth: 0,  // One-time ~$5/GB permanent
    hasExpiry: false,
    maxFileSize: 100 << 20,  // 100MB per tx (can bundle)
  );

  static const storj = StorageProviderConfig(
    name: 'storj',
    costPerGbMonth: 4,  // ~$4/GB/month
    hasExpiry: true,
  );
}
