/// Types of feed items supported by the decentralized feed.
enum FeedItemType { video, image, text, story, miniApp }

/// Author info resolved from on-chain identity + IPFS profile.
class FeedAuthor {
  final String id;
  final String username;
  final String displayName;

  /// IPFS CID for avatar, or null.
  final String? avatarCid;

  /// Legacy URL fallback.
  final String? avatarUrl;
  final bool isVerified;

  const FeedAuthor({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarCid,
    this.avatarUrl,
    this.isVerified = false,
  });
}

/// A feed item sourced from chain events + IPFS content.
///
/// The [mediaCid] and [avatarCid] are IPFS content identifiers.
/// The [mediaUrl] and [avatarUrl] are legacy Go-service URLs (fallback).
class FeedItem {
  final String id;

  /// IPFS CID of the content metadata JSON.
  final String contentCid;

  final FeedItemType type;
  final FeedAuthor author;
  final String? content;

  /// IPFS CID of the media file (if any).
  final String? mediaCid;

  /// Legacy URL fallback for media.
  final String? mediaUrl;

  /// IPFS CID of the thumbnail.
  final String? thumbnailCid;

  /// Legacy URL fallback for thumbnail.
  final String? thumbnail;
  final int? duration;
  final int likes;
  final int comments;
  final int shares;
  final int views;
  final bool hasLiked;
  final bool hasSaved;
  final double score;
  final Map<String, String>? data;
  final DateTime createdAt;

  const FeedItem({
    required this.id,
    required this.contentCid,
    required this.type,
    required this.author,
    this.content,
    this.mediaCid,
    this.mediaUrl,
    this.thumbnailCid,
    this.thumbnail,
    this.duration,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.views = 0,
    this.hasLiked = false,
    this.hasSaved = false,
    this.score = 0,
    this.data,
    required this.createdAt,
  });

  FeedItem copyWith({
    int? likes,
    int? comments,
    int? shares,
    int? views,
    bool? hasLiked,
    bool? hasSaved,
    double? score,
  }) {
    return FeedItem(
      id: id,
      contentCid: contentCid,
      type: type,
      author: author,
      content: content,
      mediaCid: mediaCid,
      mediaUrl: mediaUrl,
      thumbnailCid: thumbnailCid,
      thumbnail: thumbnail,
      duration: duration,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      views: views ?? this.views,
      hasLiked: hasLiked ?? this.hasLiked,
      hasSaved: hasSaved ?? this.hasSaved,
      score: score ?? this.score,
      data: data ?? this.data,
      createdAt: createdAt,
    );
  }
}
