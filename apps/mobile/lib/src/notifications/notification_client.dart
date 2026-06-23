import 'dart:async';

/// Local notification state — no Go backend.
///
/// Notifications are generated locally from chain events
/// (follows, likes, chat messages) rather than fetched from a server.
enum NotificationType {
  chatMessage,
  feedLike,
  feedComment,
  feedShare,
  follow,
  mention,
  miniApp,
  system,
}

class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, String>? data;
  final String? actorId;
  final String? actorName;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    this.actorId,
    this.actorName,
    this.read = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: _parseType(json['type'] as String),
      title: json['title'] as String,
      body: json['body'] as String,
      data: (json['data'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, v as String)),
      actorId: json['actor_id'] as String?,
      actorName: json['actor_name'] as String?,
      read: json['read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static NotificationType _parseType(String t) {
    switch (t) {
      case 'chat_message': return NotificationType.chatMessage;
      case 'feed_like': return NotificationType.feedLike;
      case 'feed_comment': return NotificationType.feedComment;
      case 'feed_share': return NotificationType.feedShare;
      case 'follow': return NotificationType.follow;
      case 'mention': return NotificationType.mention;
      case 'mini_app': return NotificationType.miniApp;
      default: return NotificationType.system;
    }
  }
}

class NotificationClient {
  final _notifController = StreamController<AppNotification>.broadcast();

  Stream<AppNotification> get onNotification => _notifController.stream;

  NotificationClient();

  Future<void> connect(String userId) async {
    // Notifications come via chain event listener, not WebSocket
  }

  void addNotification(AppNotification notification) {
    _notifController.add(notification);
  }

  Future<List<AppNotification>> getNotifications(
      String userId, {int limit = 20, int offset = 0}) async {
    return [];
  }

  Future<int> getUnreadCount(String userId) async {
    return 0;
  }

  void disconnect() {
    _notifController.close();
  }
}
