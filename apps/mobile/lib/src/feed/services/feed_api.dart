import 'dart:convert';
import 'package:notjustdex_identity_kernel/identity_kernel.dart';
import '../feed_item_model.dart';

/// Feed API client — chain+IPFS only.
///
/// No Go service fallback. Content comes from chain events + IPFS.
class FeedApiClient {
  final DecentralizedFeedService? decentralizedFeed;
  final IpfsClient? ipfs;

  FeedApiClient({
    this.decentralizedFeed,
    this.ipfs,
  });

  Future<List<FeedItem>> getFeed({
    required String userId,
    int limit = 10,
    String? cursor,
  }) async {
    if (decentralizedFeed != null) {
      final chainItems = decentralizedFeed!.loadFeed(
        limit: limit,
        beforeCursor: cursor,
      );
      return (await chainItems).map(_fromFeedItemData).toList();
    }
    return [];
  }

  Future<String> postContent({
    required String identityAddress,
    required String text,
    String? mediaCid,
    String? mediaType,
  }) async {
    if (ipfs == null) throw Exception('IPFS client not configured');

    final content = {
      'content': text,
      if (mediaCid != null) 'mediaCid': mediaCid,
      if (mediaType != null) 'mediaType': mediaType,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    final cid = await ipfs!.uploadJson(content);
    return cid;
  }

  Future<void> like(String userId, String itemId) async {
    if (decentralizedFeed != null) {
      await decentralizedFeed!.like(itemId, userId);
    }
  }

  Future<void> unlike(String userId, String itemId) async {
    if (decentralizedFeed != null) {
      await decentralizedFeed!.unlike(itemId);
    }
  }

  Future<void> share(String userId, String itemId) async {
    // Local-only for now
  }

  Future<void> view(String itemId) async {
    if (decentralizedFeed != null) {
      decentralizedFeed!.view(itemId);
    }
  }

  FeedItem _fromFeedItemData(FeedItemData data) {
    FeedItemType type = FeedItemType.text;
    if (data.mediaType == 'video') type = FeedItemType.video;
    else if (data.mediaType == 'image') type = FeedItemType.image;
    else if (data.mediaType == 'story') type = FeedItemType.story;

    return FeedItem(
      id: data.id,
      contentCid: data.contentCid,
      type: type,
      author: FeedAuthor(
        id: data.authorAddress,
        username: data.username,
        displayName: data.displayName,
        avatarCid: data.avatarCid,
      ),
      content: data.content,
      mediaCid: data.mediaCid,
      likes: data.likes,
      comments: data.comments,
      shares: data.shares,
      views: data.views,
      hasLiked: data.hasLiked,
      score: data.score,
      createdAt: data.createdAt,
    );
  }
}
