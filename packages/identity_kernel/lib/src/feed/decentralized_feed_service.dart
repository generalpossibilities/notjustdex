import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../chain/an_identity_contract.dart';
import '../chain/an_light_client.dart';
import '../ipfs/ipfs_client.dart';
import '../models/user_identity.dart';

/// FeedItem from decentralized sources (chain + IPFS).
class FeedItemData {
  final String id;
  final String contentCid;
  final String authorAddress;
  final String username;
  final String displayName;
  final String? avatarCid;
  final String? content;
  final String? mediaCid;
  final String? mediaType;
  final int likes;
  final int comments;
  final int shares;
  final int views;
  final bool hasLiked;
  final double score;
  final DateTime createdAt;

  const FeedItemData({
    required this.id,
    required this.contentCid,
    required this.authorAddress,
    required this.username,
    required this.displayName,
    this.avatarCid,
    this.content,
    this.mediaCid,
    this.mediaType,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    this.views = 0,
    this.hasLiked = false,
    this.score = 0,
    required this.createdAt,
  });

  FeedItemData copyWith({
    int? likes,
    int? comments,
    int? shares,
    int? views,
    bool? hasLiked,
    double? score,
  }) {
    return FeedItemData(
      id: id,
      contentCid: contentCid,
      authorAddress: authorAddress,
      username: username,
      displayName: displayName,
      avatarCid: avatarCid,
      content: content,
      mediaCid: mediaCid,
      mediaType: mediaType,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      views: views ?? this.views,
      hasLiked: hasLiked ?? this.hasLiked,
      score: score ?? this.score,
      createdAt: createdAt,
    );
  }
}

/// Decentralized feed — computed from chain events + IPFS content.
///
/// No Go feed service. Feed items come from:
///   1. On-chain PostContent events (CID, author, timestamp)
///   2. IPFS content fetch (by CID from the event)
///   3. Local scoring (time decay + engagement weights)
class DecentralizedFeedService {
  final AnIdentityContract _identityContract;
  final AnLightClient _lightClient;
  final IpfsClient _ipfs;
  final List<FeedItemData> _items = [];
  StreamSubscription? _contentSubscription;

  DecentralizedFeedService({
    required AnIdentityContract identityContract,
    required AnLightClient lightClient,
    required IpfsClient ipfs,
  })  : _identityContract = identityContract,
        _lightClient = lightClient,
        _ipfs = ipfs;

  List<FeedItemData> get items => List.unmodifiable(_items);

  /// Start listening to new content post events from the chain.
  void startListening() {
    _contentSubscription = _identityContract.onContentPosted().listen(
      (event) async {
        final cid = event.args['contentHash'] as String?;
        final authorAddress = event.args['address'] as String?;
        if (cid == null || authorAddress == null) return;

        final item = await _fetchFeedItem(cid, authorAddress);
        if (item != null) {
          _items.insert(0, item);
          _recalculateScores();
        }
      },
      onError: (e) {
        // Chain subscription error — feed works with cached items
      },
    );
  }

  /// Fetch a batch of feed items from chain events + IPFS.
  Future<List<FeedItemData>> loadFeed({
    int limit = 20,
    String? beforeCursor,
  }) async {
    final startIndex = beforeCursor != null
        ? _items.indexWhere((i) => i.id == beforeCursor) + 1
        : 0;
    if (startIndex < _items.length) {
      return _items.sublist(startIndex, (startIndex + limit).clamp(0, _items.length))
        ..sort((a, b) => b.score.compareTo(a.score));
    }

    // Fetch from chain if not enough cached items
    await _fetchFromChain(limit);
    return _items.sorted((a, b) => b.score.compareTo(a.score)).take(limit).toList();
  }

  /// Like/unlike a feed item (submits to chain).
  Future<void> like(String itemId, String identityAddress) async {
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx == -1) return;

    final item = _items[idx];
    if (item.hasLiked) return;

    // Optimistic update: apply locally first
    _items[idx] = item.copyWith(
      likes: item.likes + 1,
      hasLiked: true,
    );
    _recalculateScores();

    // Submit like to chain — rollback on failure
    final ok = await _identityContract.follow(identityAddress, item.authorAddress);
    if (!ok) {
      _items[idx] = item.copyWith(
        likes: item.likes,
        hasLiked: false,
      );
      _recalculateScores();
    }
  }

  Future<void> unlike(String itemId) async {
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx == -1) return;

    final item = _items[idx];
    if (!item.hasLiked) return;

    _items[idx] = item.copyWith(
      likes: (item.likes - 1).clamp(0, item.likes),
      hasLiked: false,
    );
    _recalculateScores();
  }

  /// Record a view (local only — views are not on-chain).
  void view(String itemId) {
    final idx = _items.indexWhere((i) => i.id == itemId);
    if (idx == -1) return;
    _items[idx] = _items[idx].copyWith(views: _items[idx].views + 1);
    _recalculateScores();
  }

  Future<FeedItemData?> _fetchFeedItem(String cid, String authorAddress) async {
    try {
      final contentJson = await _ipfs.fetchJson(cid);
      final identity = await _identityContract.getIdentity(authorAddress);

      return FeedItemData(
        id: cid,
        contentCid: cid,
        authorAddress: authorAddress,
        username: identity?.username.value ?? authorAddress.substring(0, 8),
        displayName: identity?.profile.displayName ?? 'Unknown',
        avatarCid: identity?.profile.avatarCid,
        content: contentJson['content'] as String?,
        mediaCid: contentJson['mediaCid'] as String?,
        mediaType: contentJson['mediaType'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (contentJson['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _fetchFromChain(int limit) async {
    // In production: query chain for recent PostContent events.
    // Stub: no-op since chain events aren't available in dev.
  }

  /// Time-decay scoring: same formula as Go feed service.
  /// score = (likes*1 + comments*2 + shares*3 + views*0.1) * timeDecay * typeBoost
  void _recalculateScores() {
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      final age = now - (item.createdAt.millisecondsSinceEpoch / 1000);
      final timeDecay = _timeDecay(age);
      final typeBoost = item.mediaType != null ? _typeBoost(item.mediaType!) : 1.0;
      final engagement = item.likes * 1 +
          item.comments * 2 +
          item.shares * 3 +
          item.views * 0.1;

      _items[i] = item.copyWith(
        score: engagement * timeDecay * typeBoost,
      );
    }
    _items.sort((a, b) => b.score.compareTo(a.score));
  }

  double _timeDecay(double ageHours) {
    if (ageHours <= 1) return 1.0;
    if (ageHours <= 24) return 0.8;
    if (ageHours <= 72) return 0.5;
    if (ageHours <= 168) return 0.2;
    return 0.05;
  }

  double _typeBoost(String mediaType) {
    switch (mediaType) {
      case 'video':
        return 1.3;
      case 'story':
        return 1.2;
      case 'image':
        return 1.1;
      default:
        return 1.0;
    }
  }

  void dispose() {
    _contentSubscription?.cancel();
  }
}

extension _SortedIterable<T> on Iterable<T> {
  List<T> sorted(int Function(T, T) compare) {
    final list = toList();
    list.sort(compare);
    return list;
  }
}
