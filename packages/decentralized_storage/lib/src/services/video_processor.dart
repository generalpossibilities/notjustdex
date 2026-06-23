import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

/// Options for video processing.
class VideoProcessingOptions {
  /// Target segment duration in seconds.
  final int segmentDuration;

  /// Enable multi-resolution variants.
  final bool enableVariants;

  /// Resolutions to transcode (e.g. ['360p', '720p', '1080p']).
  final List<String> resolutions;

  /// Generate thumbnail at this time offset (seconds).
  final int? thumbnailOffset;

  const VideoProcessingOptions({
    this.segmentDuration = 6,
    this.enableVariants = false,
    this.resolutions = const ['720p'],
    this.thumbnailOffset = 3,
  });
}

/// Result of video processing.
class VideoProcessingResult {
  /// CID of the master HLS playlist.
  final String masterPlaylistCid;

  /// CIDs of all HLS segments.
  final List<String> segmentCids;

  /// Thumbnail CID (if generated).
  final String? thumbnailCid;

  /// Variant playlists CID per resolution.
  final Map<String, String>? variantPlaylistCids;

  const VideoProcessingResult({
    required this.masterPlaylistCid,
    required this.segmentCids,
    this.thumbnailCid,
    this.variantPlaylistCids,
  });
}

/// Client-side video transcoder using FFmpeg WASM (web) or native FFmpeg (mobile).
///
/// Splits video into HLS chunks, uploads each chunk to IPFS,
/// creates M3U8 playlists referencing IPFS CIDs via gateway URLs.
class VideoProcessor {
  final Function(Uint8List data, String filename) _uploadToIpfs;

  VideoProcessor({
    required Function(Uint8List data, String filename) uploadToIpfs,
  }) : _uploadToIpfs = uploadToIpfs;

  /// Process a video file: transcode to HLS, upload segments to IPFS,
  /// return manifest with all CIDs.
  Future<VideoProcessingResult> processVideo({
    required Uint8List videoBytes,
    required String originalFilename,
    VideoProcessingOptions options = const VideoProcessingOptions(),
  }) async {
    // In production: call FFmpeg to transcode into HLS segments
    // FFmpeg command: ffmpeg -i input.mp4 -c:v libx264 -c:a aac -hls_time 6 -hls_playlist_type vod output.m3u8
    //
    // For now: simulate the HLS segmentation process
    return _simulateProcessing(videoBytes, originalFilename, options);
  }

  /// Generate a thumbnail from video bytes.
  Future<Uint8List?> generateThumbnail(Uint8List videoBytes, {int atSeconds = 3}) async {
    // In production: ffmpeg -ss 3 -i input.mp4 -vframes 1 -s 320x180 thumb.jpg
    // For now: return null (FFmpeg not available in Dart)
    return null;
  }

  /// Simulate processing — creates fake segment boundaries for development.
  Future<VideoProcessingResult> _simulateProcessing(
    Uint8List videoBytes,
    String filename,
    VideoProcessingOptions options,
  ) async {
    // Simulate segmentation: divide video bytes into N chunks
    final chunkSize = 1024 * 256; // 256KB per simulated segment
    final segmentCount = (videoBytes.length / chunkSize).ceil().clamp(1, 50);
    final segmentCids = <String>[];

    for (var i = 0; i < segmentCount; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize).clamp(0, videoBytes.length);
      final segmentBytes = videoBytes.sublist(start, end);

      // Upload segment to IPFS
      final cid = await _uploadToIpfs(segmentBytes, 'segment_$i.ts');
      segmentCids.add(cid);
    }

    // Generate master playlist M3U8 referencing segments via IPFS gateway
    final playlistContent = _generateHlsPlaylist(segmentCids, options.segmentDuration);
    final playlistBytes = Uint8List.fromList(utf8.encode(playlistContent));
    final masterCid = await _uploadToIpfs(playlistBytes, 'master.m3u8');

    // Generate thumbnail if requested
    String? thumbnailCid;
    if (options.thumbnailOffset != null) {
      final thumb = await generateThumbnail(videoBytes, atSeconds: options.thumbnailOffset!);
      if (thumb != null) {
        thumbnailCid = await _uploadToIpfs(thumb, 'thumbnail.jpg');
      }
    }

    return VideoProcessingResult(
      masterPlaylistCid: masterCid,
      segmentCids: segmentCids,
      thumbnailCid: thumbnailCid,
    );
  }

  /// Generate HLS playlist M3U8 content with IPFS gateway URLs.
  String _generateHlsPlaylist(List<String> segmentCids, int segmentDuration) {
    final buf = StringBuffer();
    buf.writeln('#EXTM3U');
    buf.writeln('#EXT-X-VERSION:3');
    buf.writeln('#EXT-X-TARGETDURATION:$segmentDuration');
    buf.writeln('#EXT-X-MEDIA-SEQUENCE:0');
    buf.writeln('#EXT-X-PLAYLIST-TYPE:VOD');

    for (var i = 0; i < segmentCids.length; i++) {
      buf.writeln('#EXTINF:$segmentDuration.000,');
      // Segment fetched via IPFS gateway — app replaces gateway URL at runtime
      buf.writeln('ipfs://${segmentCids[i]}');
    }

    buf.writeln('#EXT-X-ENDLIST');
    return buf.toString();
  }
}
