import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TourPage extends StatefulWidget {
  const TourPage({super.key});

  @override
  State<TourPage> createState() => _TourPageState();
}

class _TourPageState extends State<TourPage> {
  final _pageController = PageController();
  int _currentPage = 0;

  static final _tourItems = [
    _TourItem(
      type: 'video',
      title: 'Welcome to DexChats',
      subtitle: 'Connect. Create. Own.',
      color: Color(0xFF6C63FF),
      icon: Icons.play_circle,
    ),
    _TourItem(
      type: 'image',
      title: 'Trending Now',
      subtitle: 'See what everyone is talking about',
      color: Color(0xFFFF6B6B),
      icon: Icons.image,
    ),
    _TourItem(
      type: 'text',
      title: 'Decentralized Social',
      subtitle: 'Your identity, your data, your rules',
      color: Color(0xFF4ECDC4),
      icon: Icons.auto_awesome,
    ),
    _TourItem(
      type: 'miniApp',
      title: 'Mini Apps',
      subtitle: 'Wallet, DAO, Creator Studio & more',
      color: Color(0xFFFFD93D),
      icon: Icons.apps,
    ),
  ];

  bool get _isLastPage => _currentPage == _tourItems.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _tourItems.length,
            itemBuilder: (_, i) => _buildFeedCard(_tourItems[i], theme),
          ),

          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('DexChats', style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                )),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => context.push('/auth', extra: 'login'),
                      child: const Text('Log In'),
                    ),
                    FilledButton(
                      onPressed: () => context.push('/auth', extra: 'register'),
                      child: const Text('Sign Up'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bottom
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 0,
            right: 0,
            child: _isLastPage
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        FilledButton(
                          onPressed: () => context.push('/auth', extra: 'register'),
                          child: const Text('Create Account'),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => context.push('/auth', extra: 'login'),
                          child: const Text('I already have an account'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_tourItems.length, (i) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _currentPage == i ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _currentPage == i
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      if (_currentPage == 0) ...[
                        const SizedBox(height: 12),
                        Icon(Icons.swipe_vertical, color: Colors.white38, size: 28),
                        const SizedBox(height: 4),
                        Text('Swipe up to explore',
                            style: TextStyle(color: Colors.white38, fontSize: 12)),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedCard(_TourItem item, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [item.color.withValues(alpha: 0.8), theme.scaffoldBackgroundColor],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, size: 72, color: Colors.white.withValues(alpha: 0.9)),
                const SizedBox(height: 24),
                Text(item.title, style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                Text(item.subtitle, style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7))),
                const SizedBox(height: 32),
                Chip(
                  label: Text(item.type.toUpperCase(), style: const TextStyle(fontSize: 10)),
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  side: BorderSide.none,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TourItem {
  final String type;
  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;
  const _TourItem({
    required this.type, required this.title, required this.subtitle,
    required this.color, required this.icon,
  });
}
