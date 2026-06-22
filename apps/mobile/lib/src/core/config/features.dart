import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';

class FeatureFlags {
  final bool feed;
  final bool chat;
  final bool miniApps;
  final bool notifications;
  final bool creatorEconomy;
  final bool search;
  final bool moderation;
  final bool media;
  final bool analytics;
  final bool dao;

  // Service hosts (for connecting to Go backends)
  final String authHost;
  final String usersHost;
  final String feedHost;
  final String chatHost;
  final String notificationsHost;
  final String searchHost;
  final String creatorEconomyHost;
  final String moderationHost;
  final String mediaHost;
  final String analyticsHost;
  final String daoHost;

  const FeatureFlags({
    this.feed = true,
    this.chat = true,
    this.miniApps = true,
    this.notifications = true,
    this.creatorEconomy = true,
    this.search = true,
    this.moderation = true,
    this.media = true,
    this.analytics = true,
    this.dao = false,
    this.authHost = 'http://localhost:8081',
    this.usersHost = 'http://localhost:8082',
    this.feedHost = 'http://localhost:8083',
    this.chatHost = 'http://localhost:8085',
    this.notificationsHost = 'http://localhost:8087',
    this.searchHost = 'http://localhost:8086',
    this.creatorEconomyHost = 'http://localhost:8092',
    this.moderationHost = 'http://localhost:8090',
    this.mediaHost = 'http://localhost:8088',
    this.analyticsHost = 'http://localhost:8089',
    this.daoHost = 'http://localhost:8091',
  });

  static const production = FeatureFlags();

  factory FeatureFlags.fromJson(Map<String, dynamic> json) {
    String host(String key, String fallback) {
      final s = json[key] as Map<String, dynamic>?;
      if (s == null) return fallback;
      final host = s['service_host'] as String?;
      if (host == null) return fallback;
      return 'http://$host';
    }

    return FeatureFlags(
      feed: json['feed']?['enabled'] as bool? ?? true,
      chat: json['chat']?['enabled'] as bool? ?? true,
      miniApps: json['mini_apps']?['enabled'] as bool? ?? true,
      notifications: json['notifications']?['enabled'] as bool? ?? true,
      creatorEconomy: json['creator_economy']?['enabled'] as bool? ?? true,
      search: json['search']?['enabled'] as bool? ?? true,
      moderation: json['moderation']?['enabled'] as bool? ?? true,
      media: json['media']?['enabled'] as bool? ?? true,
      analytics: json['analytics']?['enabled'] as bool? ?? true,
      dao: json['dao']?['enabled'] as bool? ?? false,
      authHost: host('auth', 'http://localhost:8081'),
      usersHost: host('users', 'http://localhost:8082'),
      feedHost: host('feed', 'http://localhost:8083'),
      chatHost: host('chat', 'http://localhost:8085'),
      notificationsHost: host('notifications', 'http://localhost:8087'),
      searchHost: host('search', 'http://localhost:8086'),
      creatorEconomyHost: host('creator_economy', 'http://localhost:8092'),
      moderationHost: host('moderation', 'http://localhost:8090'),
      mediaHost: host('media', 'http://localhost:8088'),
      analyticsHost: host('analytics', 'http://localhost:8089'),
      daoHost: host('dao', 'http://localhost:8091'),
    );
  }

  static Future<FeatureFlags> load() async {
    try {
      final file = File('config/features.yaml');
      if (await file.exists()) {
        final content = await file.readAsString();
        final yaml = loadYaml(content) as YamlMap;
        final map = yaml.cast<String, dynamic>();
        return FeatureFlags.fromJson(map);
      }
    } catch (_) {}
    return production;
  }
}
