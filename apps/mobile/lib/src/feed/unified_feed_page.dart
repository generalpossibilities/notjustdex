import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'feed_item_model.dart';
import 'services/feed_api.dart';

const _feedHost = '10.0.2.2:8083';

class UnifiedFeedPage extends StatefulWidget {
  const UnifiedFeedPage({super.key});

  @override
  State<UnifiedFeedPage> createState() => _UnifiedFeedPageState();
}

class _UnifiedFeedPageState extends State<UnifiedFeedPage> {
  final _pageController = PageController();
  final _feedItems = <FeedItem>[];
  int _currentIndex = 0;
  String? _cursor;
  bool _loading = false;
  final _api = FeedApiClient(baseUrl: 'http://$_feedHost');

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final items = await _api.getFeed(
        userId: 'current_user',
        cursor: _cursor,
      );
      if (!mounted) return;
      setState(() {
        _feedItems.addAll(items);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
      if (_feedItems.isEmpty) _loadMock();
    }
  }

  void _loadMock() {
    _feedItems.addAll(_mockFeed());
    setState(() {});
  }

  void _onPageChanged(int i) {
    setState(() => _currentIndex = i);
    _api.view(_feedItems[i].id);
    if (i >= _feedItems.length - 2) _loadFeed();
  }

  void _toggleLike(int i) async {
    final item = _feedItems[i];
    setState(() {
      _feedItems[i] = item.copyWith(
        hasLiked: !item.hasLiked,
        likes: item.hasLiked ? item.likes - 1 : item.likes + 1,
      );
    });
    if (item.hasLiked) {
      await _api.unlike('current_user', item.id);
    } else {
      await _api.like('current_user', item.id);
    }
  }

  void _toggleSave(int i) {
    setState(() {
      final item = _feedItems[i];
      _feedItems[i] = item.copyWith(hasSaved: !item.hasSaved);
    });
  }

  void _openMiniApp(FeedItem item) {
    final appId = item.data?['app_id'] ?? 'wallet';
    context.push('/miniapps/open', extra: {
      'app': appId,
    });
  }

  void _showComments(BuildContext context, FeedItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      isScrollControlled: true,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('Comments (${item.comments})',
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const Expanded(
              child: Center(child: Text('No comments yet')),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _feedItems.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _feedItems.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (_, i) => _FeedCard(
                item: _feedItems[i],
                isActive: i == _currentIndex,
                onLike: () => _toggleLike(i),
                onSave: () => _toggleSave(i),
                onShare: () {},
                onComment: () => _showComments(context, _feedItems[i]),
                onOpenMiniApp: _feedItems[i].type == FeedItemType.miniApp
                    ? () => _openMiniApp(_feedItems[i])
                    : null,
              ),
            ),
    );
  }

  List<FeedItem> _mockFeed() {
    return [
      FeedItem(
        id: '1', type: FeedItemType.video,
        author: const FeedAuthor(id: 'a1', username: 'alice', displayName: 'Alice', isVerified: true),
        content: 'Morning run in the park! 🏃‍♂️', likes: 142, comments: 23, shares: 12, views: 3400,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      FeedItem(
        id: '2', type: FeedItemType.image,
        author: const FeedAuthor(id: 'a2', username: 'bob', displayName: 'Bob'),
        content: 'Sunset from the rooftop 🌅', likes: 89, comments: 8, shares: 3, views: 1200,
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      FeedItem(
        id: '3', type: FeedItemType.miniApp,
        author: const FeedAuthor(id: 'system', username: 'dexchats', displayName: 'DexChats'),
        content: '🎮 Play the latest games in Games Hub',
        likes: 345, comments: 12, shares: 56, views: 8900, data: {'app_id': 'games'},
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      FeedItem(
        id: '4', type: FeedItemType.text,
        author: const FeedAuthor(id: 'a3', username: 'charlie', displayName: 'Charlie', isVerified: true),
        content: 'Hot take: The best code is the code you don\'t write. Think about it.',
        likes: 234, comments: 56, shares: 45, views: 5600,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      FeedItem(
        id: '5', type: FeedItemType.video,
        author: const FeedAuthor(id: 'a4', username: 'diana', displayName: 'Diana'),
        content: 'Cooking tutorial: Perfect pasta aglio e olio 🍝',
        duration: 60, likes: 312, comments: 41, shares: 28, views: 8200,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      FeedItem(
        id: '6', type: FeedItemType.story,
        author: const FeedAuthor(id: 'a5', username: 'elena', displayName: 'Elena'),
        content: 'Good morning from Tokyo! 🇯🇵', likes: 67, comments: 5, shares: 2, views: 900,
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      FeedItem(
        id: '7', type: FeedItemType.miniApp,
        author: const FeedAuthor(id: 'system', username: 'dexchats', displayName: 'DexChats'),
        content: '💎 Check out the NFT Marketplace',
        likes: 567, comments: 34, shares: 89, views: 12000, data: {'app_id': 'market'},
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      FeedItem(
        id: '8', type: FeedItemType.video,
        author: const FeedAuthor(id: 'a3', username: 'charlie', displayName: 'Charlie', isVerified: true),
        content: 'Flutter vs React Native — Honest comparison',
        duration: 180, likes: 567, comments: 89, shares: 67, views: 15000,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ];
  }
}

class _FeedCard extends StatefulWidget {
  final FeedItem item;
  final bool isActive;
  final VoidCallback onLike;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onComment;
  final VoidCallback? onOpenMiniApp;

  const _FeedCard({
    required this.item,
    required this.isActive,
    required this.onLike,
    required this.onSave,
    required this.onShare,
    required this.onComment,
    this.onOpenMiniApp,
  });

  @override
  State<_FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<_FeedCard> {
  var _showHeart = false;

  void _handleDoubleTap() {
    setState(() => _showHeart = true);
    widget.onLike();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _showHeart = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final item = widget.item;

    if (item.type == FeedItemType.miniApp) {
      return _MiniAppCard(item: item, onOpen: widget.onOpenMiniApp);
    }

    final color = _cardColor(item.type);
    final icon = _typeIcon(item.type);

    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: Container(
        width: size.width,
        height: size.height,
        color: color,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (item.mediaUrl != null && item.mediaUrl!.isNotEmpty)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(icon, size: 64, color: Colors.white38),
                  ),
                ),
              ),

            if (_showHeart)
              Center(
                child: Icon(Icons.favorite, size: 100, color: Colors.white.withValues(alpha: 0.9)),
              ),

            Positioned(
              left: 16,
              right: 80,
              bottom: 100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.duration != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatDuration(item.duration!),
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    item.content ?? '',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w500, height: 1.3,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(item.author.username[0].toUpperCase(),
                            style: const TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(item.author.displayName,
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                              if (item.author.isVerified)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Icon(Icons.verified,
                                      size: 14, color: theme.colorScheme.primary),
                                ),
                            ],
                          ),
                          Text('@${item.author.username}',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Positioned(
              right: 8,
              bottom: 120,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionButton(
                    icon: item.hasLiked ? Icons.favorite : Icons.favorite_border,
                    color: item.hasLiked ? Colors.red : Colors.white,
                    label: _formatCount(item.likes),
                    onTap: widget.onLike,
                  ),
                  const SizedBox(height: 16),
                  _ActionButton(
                    icon: Icons.chat_bubble_outline,
                    color: Colors.white,
                    label: _formatCount(item.comments),
                    onTap: widget.onComment,
                  ),
                  const SizedBox(height: 16),
                  _ActionButton(
                    icon: Icons.reply, color: Colors.white,
                    label: _formatCount(item.shares), onTap: widget.onShare,
                  ),
                  const SizedBox(height: 16),
                  _ActionButton(
                    icon: item.hasSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: item.hasSaved ? Colors.amber : Colors.white,
                    label: '', onTap: widget.onSave,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _cardColor(FeedItemType type) {
    switch (type) {
      case FeedItemType.video: return const Color(0xFF1A1A2E);
      case FeedItemType.image: return const Color(0xFF1E2A1E);
      case FeedItemType.text: return const Color(0xFF2E1A1A);
      case FeedItemType.story: return const Color(0xFF2E2E1A);
      default: return const Color(0xFF1A1A2E);
    }
  }

  IconData _typeIcon(FeedItemType type) {
    switch (type) {
      case FeedItemType.video: return Icons.play_circle;
      case FeedItemType.image: return Icons.photo;
      case FeedItemType.text: return Icons.article;
      case FeedItemType.story: return Icons.auto_stories;
      default: return Icons.widgets;
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }
}

class _MiniAppCard extends StatelessWidget {
  final FeedItem item;
  final VoidCallback? onOpen;

  const _MiniAppCard({required this.item, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    return Container(
      width: size.width,
      height: size.height,
      color: const Color(0xFF1A1A2E),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.3),
                  const Color(0xFF0D0D0D),
                ],
              ),
            ),
          ),
          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(Icons.widgets_outlined,
                      size: 40, color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  item.content ?? 'Open Mini App',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon, required this.color,
    required this.label, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}
