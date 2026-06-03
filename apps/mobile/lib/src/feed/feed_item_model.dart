enum FeedItemType { video, image, text, story, miniApp }


class FeedAuthor {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isVerified;

  const FeedAuthor({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.isVerified = false,
  });
}

class FeedItem {
  final String id;
  final FeedItemType type;
  final FeedAuthor author;
  final String? content;
  final String? mediaUrl;
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
    required this.type,
    required this.author,
    this.content,
    this.mediaUrl,
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
    Map<String, String>? data,
  }) {
    return FeedItem(
      id: id,
      type: type,
      author: author,
      content: content,
      mediaUrl: mediaUrl,
      thumbnail: thumbnail,
      duration: duration,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      views: views ?? this.views,
      hasLiked: hasLiked ?? this.hasLiked,
      hasSaved: hasSaved ?? this.hasSaved,
      score: score,
      data: data ?? this.data,
      createdAt: createdAt,
    );
  }
}
