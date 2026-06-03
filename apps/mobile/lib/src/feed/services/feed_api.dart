import 'dart:convert';
import 'dart:io';
import '../feed_item_model.dart';

class FeedApiClient {
  final String baseUrl;

  FeedApiClient({required this.baseUrl});

  Future<List<FeedItem>> getFeed({
    required String userId,
    int limit = 10,
    String? cursor,
  }) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse(
        '$baseUrl/feed/?user_id=$userId&limit=$limit${cursor != null ? '&cursor=$cursor' : ''}',
      );
      final req = await client.getUrl(uri);
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      return (json['items'] as List)
          .map((e) => _parseFeedItem(e as Map<String, dynamic>))
          .toList();
    } finally {
      client.close();
    }
  }

  Future<void> like(String userId, String itemId) async {
    await _post('/feed/like', {'user_id': userId, 'item_id': itemId});
  }

  Future<void> unlike(String userId, String itemId) async {
    await _post('/feed/unlike', {'user_id': userId, 'item_id': itemId});
  }

  Future<void> share(String userId, String itemId) async {
    await _post('/feed/share', {'user_id': userId, 'item_id': itemId});
  }

  Future<void> view(String itemId) async {
    final client = HttpClient();
    try {
      await client.postUrl(Uri.parse('$baseUrl/feed/view?item_id=$itemId'));
    } finally {
      client.close();
    }
  }

  Future<void> _post(String path, Map<String, dynamic> body) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(Uri.parse('$baseUrl$path'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
      await req.close();
    } finally {
      client.close();
    }
  }

  FeedItem _parseFeedItem(Map<String, dynamic> json) {
    return FeedItem(
      id: json['id'] as String,
      type: _parseType(json['type'] as String),
      author: FeedAuthor(
        id: json['author']?['id'] as String? ?? '',
        username: json['author']?['username'] as String? ?? '',
        displayName: json['author']?['display_name'] as String? ?? '',
        avatarUrl: json['author']?['avatar_url'] as String?,
        isVerified: json['author']?['is_verified'] as bool? ?? false,
      ),
      content: json['content'] as String?,
      mediaUrl: json['media_url'] as String?,
      thumbnail: json['thumbnail'] as String?,
      duration: json['duration'] as int?,
      likes: json['likes'] as int? ?? 0,
      comments: json['comments'] as int? ?? 0,
      shares: json['shares'] as int? ?? 0,
      views: json['views'] as int? ?? 0,
      hasLiked: json['has_liked'] as bool? ?? false,
      hasSaved: json['has_saved'] as bool? ?? false,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  FeedItemType _parseType(String t) {
    switch (t) {
      case 'video': return FeedItemType.video;
      case 'image': return FeedItemType.image;
      case 'text': return FeedItemType.text;
      case 'story': return FeedItemType.story;
      default: return FeedItemType.text;
    }
  }
}
