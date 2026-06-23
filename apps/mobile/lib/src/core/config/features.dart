import 'dart:convert';
import 'dart:io';
import 'package:yaml/yaml.dart';

/// App configuration — only feature flags, no Go service hosts.
///
/// In a fully decentralized app, the chain + IPFS are the backend.
/// No service hosts are needed.
class AppConfig {
  final FeatureFlags features;

  const AppConfig({
    this.features = const FeatureFlags(),
  });

  factory AppConfig.fromDefine() {
    return AppConfig(
      features: const FeatureFlags(),
    );
  }

  static Future<AppConfig> load() async {
    final fromDefine = AppConfig.fromDefine();
    try {
      final file = File('config/features.yaml');
      if (await file.exists()) {
        final content = await file.readAsString();
        final yaml = loadYaml(content) as YamlMap;
        final map = yaml.cast<String, dynamic>();
        return AppConfig(
          features: FeatureFlags.fromJson(map),
        );
      }
    } catch (_) {}
    return fromDefine;
  }
}

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
  final bool vault;

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
    this.vault = true,
  });

  static const production = FeatureFlags();

  factory FeatureFlags.fromJson(Map<String, dynamic> json) {
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
      vault: json['vault']?['enabled'] as bool? ?? true,
    );
  }
}
