import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  WebSocket? _ws;
  final _notifController = StreamController<AppNotification>.broadcast();

  Stream<AppNotification> get onNotification => _notifController.stream;

  final String _baseUrl;

  NotificationClient({required String baseUrl}) : _baseUrl = baseUrl;

  Future<void> connect(String userId) async {
    _ws = await WebSocket.connect('ws://$_baseUrl/ws?user_id=$userId');
    _ws!.listen(
      (data) {
        final json = jsonDecode(data as String) as Map<String, dynamic>;
        if (json['type'] == 'notification') {
          _notifController.add(
            AppNotification.fromJson(
              json['notification'] as Map<String, dynamic>,
            ),
          );
        }
      },
      onError: (e) => print('Notification WS error: $e'),
      onDone: () => print('Notification WS closed'),
    );
  }

  Future<List<AppNotification>> getNotifications(
      String userId, {int limit = 20, int offset = 0}) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(
        Uri.parse('$_baseUrl/api/notifications?user_id=$userId&limit=$limit&offset=$offset'),
      );
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      return (json['notifications'] as List)
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList();
    } finally {
      client.close();
    }
  }

  Future<int> getUnreadCount(String userId) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(
        Uri.parse('$_baseUrl/api/notifications?user_id=$userId&limit=1'),
      );
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['unread_count'] as int;
    } finally {
      client.close();
    }
  }

  Future<void> markRead(String userId, {List<String>? ids}) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(
        Uri.parse('$_baseUrl/api/notifications/read?user_id=$userId'),
      );
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'ids': ids ?? []}));
      await req.close();
    } finally {
      client.close();
    }
  }

  void disconnect() {
    _ws?.close();
    _notifController.close();
  }
}
