import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:notjustdex_identity_kernel/identity_kernel.dart';
import '../models/content_manifest.dart';
import 'video_processor.dart';
import 'storage_replicator.dart';

/// Orchestrates content upload → replicate → register on chain.
///
/// Flow:
///   1. Upload raw bytes to IPFS → base CID
///   2. For video: transcode to HLS → upload segments → get playlist CID
///   3. Build ContentManifest with all CIDs
///   4. Upload manifest to IPFS → manifest CID
///   5. Store manifest CID on chain (as PostContent event)
///   6. Replicate content across multiple storage backends
///   7. Return manifest CID for use in feed posts
class ContentStorageService {
  final IpfsClient _ipfs;
  final AnIdentityContract _contract;
  final StorageReplicator _replicator;
  final VideoProcessor? _videoProcessor;

  ContentStorageService({
    required IpfsClient ipfs,
    required AnIdentityContract contract,
    required StorageReplicator replicator,
    VideoProcessor? videoProcessor,
  })  : _ipfs = ipfs,
        _contract = contract,
        _replicator = replicator,
        _videoProcessor = videoProcessor;

  /// Upload any content (image, audio, document, text).
  ///
  /// Returns the manifest CID that should be committed on chain.
  Future<ContentManifest> uploadContent({
    required Uint8List bytes,
    required String mimeType,
    required String identityAddress,
    Map<String, dynamic> metadata = const {},
    String? originalFilename,
    ReplicationPolicy replicationPolicy = const ReplicationPolicy(),
  }) async {
    final contentType = _inferContentType(mimeType);

    // 1. Upload raw bytes to IPFS
    final mediaCid = await _ipfs.uploadBytes(bytes);

    // 2. Build manifest
    final manifest = ContentManifest(
      createdAt: DateTime.now(),
      contentType: contentType,
      mimeType: mimeType,
      originalFilename: originalFilename,
      originalSize: bytes.length,
      mediaCid: mediaCid,
      metadata: metadata,
    );

    // 3. Replicate across storage providers
    final receipts = await _replicator.replicate(
      contentCid: mediaCid,
      bytes: bytes,
      mimeType: mimeType,
      policy: replicationPolicy,
    );

    // 4. Upload manifest to IPFS
    final manifestJson = manifest.toJson();
    manifestJson['storage_receipts'] = receipts.map((r) => r.toJson()).toList();
    final manifestBytes = Uint8List.fromList(utf8.encode(jsonEncode(manifestJson)));
    await _ipfs.uploadBytes(manifestBytes);

    // 5. Store on chain
    await _contract.postContent(mediaCid, identityAddress);

    return ContentManifest.fromJson(manifestJson);
  }

  /// Upload a video — transcodes to HLS, replicates all segments.
  Future<ContentManifest> uploadVideo({
    required Uint8List videoBytes,
    required String identityAddress,
    String originalFilename = 'video.mp4',
    VideoProcessingOptions processingOptions = const VideoProcessingOptions(),
    ReplicationPolicy replicationPolicy = const ReplicationPolicy(),
    Map<String, dynamic> metadata = const {},
  }) async {
    if (_videoProcessor == null) {
      throw Exception('VideoProcessor not configured');
    }

    // 1. Process video into HLS segments
    final result = await _videoProcessor.processVideo(
      videoBytes: videoBytes,
      originalFilename: originalFilename,
      options: processingOptions,
    );

    // 2. Build manifest
    final manifest = ContentManifest(
      createdAt: DateTime.now(),
      contentType: 'video',
      mimeType: 'application/x-mpegurl',
      originalFilename: originalFilename,
      originalSize: videoBytes.length,
      hlsPlaylistCid: result.masterPlaylistCid,
      hlsSegmentCids: result.segmentCids,
      thumbnailCids: result.thumbnailCid != null ? [result.thumbnailCid!] : null,
      variants: result.variantPlaylistCids,
      metadata: metadata,
    );

    // 3. Replicate manifest + playlist + segments
    final allCids = [
      result.masterPlaylistCid,
      ...result.segmentCids,
      if (result.thumbnailCid != null) result.thumbnailCid!,
    ];

    final allReceipts = <StorageReceipt>[];
    for (final cid in allCids) {
      try {
        final bytes = await _ipfs.fetchBytes(cid);
        final receipts = await _replicator.replicate(
          contentCid: cid,
          bytes: Uint8List.fromList(bytes),
          mimeType: 'video/MP2T',
          policy: replicationPolicy,
        );
        allReceipts.addAll(receipts);
      } catch (_) {}
    }

    // 4. Upload manifest to IPFS
    final manifestJson = manifest.toJson();
    manifestJson['storage_receipts'] = allReceipts.map((r) => r.toJson()).toList();
    final manifestBytes = Uint8List.fromList(utf8.encode(jsonEncode(manifestJson)));
    final manifestCid = await _ipfs.uploadBytes(manifestBytes);

    // 5. Store on chain
    await _contract.postContent(manifestCid, identityAddress);

    return ContentManifest.fromJson(manifestJson);
  }

  /// Resolve a content manifest by CID.
  Future<ContentManifest?> resolveManifest(String manifestCid) async {
    try {
      final bytes = await _ipfs.fetchBytes(manifestCid);
      final json = jsonDecode(utf8.decode(bytes.toList())) as Map<String, dynamic>;
      return ContentManifest.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Get playback URLs for a video manifest.
  /// Returns a prioritized list of sources (P2P first, gateways fallback).
  PlaybackSources getPlaybackUrls(ContentManifest manifest, {List<String> gateways = const []}) {
    if (manifest.hlsPlaylistCid == null) {
      return PlaybackSources(
        directCid: manifest.mediaCid,
        sources: manifest.mediaCid != null
            ? [PlaybackSource(url: 'ipfs://${manifest.mediaCid}', source: 'ipfs')]
            : [],
      );
    }

    final sources = <PlaybackSource>[];
    final defaultGateways = [
      'https://ipfs.io/ipfs',
      'https://cloudflare-ipfs.com/ipfs',
      'https://dweb.link/ipfs',
    ];

    // 1. HLS playlist via multiple gateways (browser HLS.js can fallback)
    for (final gw in [...gateways, ...defaultGateways]) {
      sources.add(PlaybackSource(
        url: '$gw/${manifest.hlsPlaylistCid}',
        source: 'gateway',
        label: gw,
      ));
    }

    // 2. Add variant playlists if available
    if (manifest.variants != null) {
      for (final entry in manifest.variants!.entries) {
        for (final gw in [...gateways, ...defaultGateways].take(1)) {
          sources.add(PlaybackSource(
            url: '$gw/${entry.value}',
            source: 'variant',
            label: entry.key,
          ));
        }
      }
    }

    return PlaybackSources(
      directCid: manifest.hlsPlaylistCid,
      sources: sources,
    );
  }

  String _inferContentType(String mimeType) {
    if (mimeType.startsWith('video/')) return 'video';
    if (mimeType.startsWith('image/')) return 'image';
    if (mimeType.startsWith('audio/')) return 'audio';
    return 'document';
  }
}

/// A resolvable playback source.
class PlaybackSource {
  final String url;
  final String source; // 'gateway', 'variant', 'p2p', 'ipfs'
  final String? label;

  const PlaybackSource({
    required this.url,
    required this.source,
    this.label,
  });
}

/// Ordered list of playback sources for a player to try.
class PlaybackSources {
  final String? directCid;
  final List<PlaybackSource> sources;

  const PlaybackSources({
    this.directCid,
    this.sources = const [],
  });
}
