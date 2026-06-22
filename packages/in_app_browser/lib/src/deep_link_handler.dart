class DeepLinkHandler {
  static const _scheme = 'notjustdex';
  static const _hosts = [
    'miniapp',
    'profile',
    'post',
    'chat',
    'settings',
  ];

  static DeepLinkResult? parse(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.scheme != _scheme) return null;

    final host = uri.host;
    if (!_hosts.contains(host)) return null;

    final pathSegments = uri.pathSegments;

    switch (host) {
      case 'miniapp':
        if (pathSegments.isNotEmpty) {
          return DeepLinkResult.miniApp(pathSegments.first);
        }
      case 'profile':
        if (pathSegments.isNotEmpty) {
          return DeepLinkResult.profile(pathSegments.first);
        }
      case 'post':
        if (pathSegments.isNotEmpty) {
          return DeepLinkResult.post(pathSegments.first);
        }
      case 'chat':
        if (pathSegments.isNotEmpty) {
          return DeepLinkResult.chat(pathSegments.first);
        }
      case 'settings':
        return DeepLinkResult.general('/settings${uri.path}');
    }
    return null;
  }

  static bool isNotJustDexUrl(String url) {
    return url.startsWith('$_scheme://');
  }
}

sealed class DeepLinkResult {
  const DeepLinkResult();
  factory DeepLinkResult.miniApp(String appId) = _MiniAppLink;
  factory DeepLinkResult.profile(String username) = _ProfileLink;
  factory DeepLinkResult.post(String postId) = _PostLink;
  factory DeepLinkResult.chat(String conversationId) = _ChatLink;
  factory DeepLinkResult.general(String path) = _GeneralLink;

  T map<T>({
    required T Function(String appId) miniApp,
    required T Function(String username) profile,
    required T Function(String postId) post,
    required T Function(String conversationId) chat,
    required T Function(String path) general,
  }) {
    return switch (this) {
      _MiniAppLink(:final appId) => miniApp(appId),
      _ProfileLink(:final username) => profile(username),
      _PostLink(:final postId) => post(postId),
      _ChatLink(:final conversationId) => chat(conversationId),
      _GeneralLink(:final path) => general(path),
    };
  }
}

class _MiniAppLink extends DeepLinkResult {
  final String appId;
  const _MiniAppLink(this.appId);
}

class _ProfileLink extends DeepLinkResult {
  final String username;
  const _ProfileLink(this.username);
}

class _PostLink extends DeepLinkResult {
  final String postId;
  const _PostLink(this.postId);
}

class _ChatLink extends DeepLinkResult {
  final String conversationId;
  const _ChatLink(this.conversationId);
}

class _GeneralLink extends DeepLinkResult {
  final String path;
  const _GeneralLink(this.path);
}
