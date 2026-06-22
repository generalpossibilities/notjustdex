import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'deep_link_handler.dart';

class BrowserPage extends StatefulWidget {
  final String initialUrl;
  final String? title;

  const BrowserPage({
    super.key,
    required this.initialUrl,
    this.title,
  });

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;
  bool _canGoBack = false;
  bool _canGoForward = false;
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _urlController.text = widget.initialUrl;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() {
              _progress = progress / 100;
              _isLoading = progress < 100;
            });
          },
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _urlController.text = url;
            });
          },
          onPageFinished: (url) async {
            if (!mounted) return;
            final canGoBack = await _controller.canGoBack();
            final canGoForward = await _controller.canGoForward();
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _canGoBack = canGoBack;
              _canGoForward = canGoForward;
            });
          },
          onNavigationRequest: (request) {
            if (DeepLinkHandler.isNotJustDexUrl(request.url)) {
              final link = DeepLinkHandler.parse(request.url);
              if (link != null && context.mounted) {
                _handleDeepLink(link);
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  void _handleDeepLink(DeepLinkResult link) {
    link.map(
      miniApp: (appId) => Navigator.pop(context, {'type': 'miniapp', 'id': appId}),
      profile: (username) => Navigator.pop(context, {'type': 'profile', 'username': username}),
      post: (postId) => Navigator.pop(context, {'type': 'post', 'id': postId}),
      chat: (conversationId) => Navigator.pop(context, {'type': 'chat', 'id': conversationId}),
      general: (path) => Navigator.pop(context, {'type': 'navigate', 'path': path}),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: widget.title != null
            ? Text(widget.title!)
            : _buildUrlBar(theme),
        actions: [
          if (_isLoading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                switch (v) {
                  case 'refresh':
                    _controller.reload();
                  case 'share':
                    // share URL
                  case 'open_external':
                    // open in external browser
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'refresh', child: Text('Refresh')),
                const PopupMenuItem(value: 'share', child: Text('Share')),
                const PopupMenuItem(value: 'open_external', child: Text('Open in Browser')),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          Expanded(child: WebViewWidget(controller: _controller)),
          _buildBottomNav(theme),
        ],
      ),
    );
  }

  Widget _buildUrlBar(ThemeData theme) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _urlController,
        style: const TextStyle(fontSize: 13),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.go,
        onSubmitted: (url) {
          final uri = Uri.tryParse(url);
          if (uri != null && uri.host.isEmpty) {
            url = 'https://$url';
          }
          _controller.loadRequest(Uri.parse(url));
        },
      ),
    );
  }

  Widget _buildBottomNav(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.surfaceContainerHighest)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _canGoBack ? () => _controller.goBack() : null,
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward),
            onPressed: _canGoForward ? () => _controller.goForward() : null,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () {
              // Open in external browser
            },
          ),
        ],
      ),
    );
  }
}
