import 'dart:async';
import 'package:flutter/material.dart';
import 'notification_client.dart';

class NotificationsPage extends StatefulWidget {
  final NotificationClient client;
  final String userId;

  const NotificationsPage({
    super.key,
    required this.client,
    required this.userId,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<AppNotification> _notifs = [];
  int _unreadCount = 0;
  StreamSubscription<AppNotification>? _sub;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = widget.client.onNotification.listen((_) => _load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final notifs = await widget.client.getNotifications(widget.userId);
    final unread = await widget.client.getUnreadCount(widget.userId);
    if (!mounted) return;
    setState(() {
      _notifs = notifs;
      _unreadCount = unread;
    });
  }

  Future<void> _markRead(AppNotification n) async {
    await widget.client.markRead(widget.userId, ids: [n.id]);
    _load();
  }

  Future<void> _markAllRead() async {
    await widget.client.markRead(widget.userId);
    _load();
  }

  IconData _iconForType(NotificationType t) {
    switch (t) {
      case NotificationType.chatMessage: return Icons.chat;
      case NotificationType.feedLike: return Icons.favorite;
      case NotificationType.feedComment: return Icons.comment;
      case NotificationType.feedShare: return Icons.reply;
      case NotificationType.follow: return Icons.person_add;
      case NotificationType.mention: return Icons.alternate_email;
      case NotificationType.miniApp: return Icons.widgets;
      case NotificationType.system: return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _notifs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('No notifications yet', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Activity from your network will appear here',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _notifs.length,
              itemBuilder: (_, i) {
                final n = _notifs[i];
                return Dismissible(
                  key: Key(n.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: theme.colorScheme.primary,
                    child: const Icon(Icons.check, color: Colors.white),
                  ),
                  onDismissed: (_) => _markRead(n),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: n.read
                          ? theme.colorScheme.surfaceVariant
                          : theme.colorScheme.primaryContainer,
                      child: Icon(_iconForType(n.type),
                          color: n.read ? Colors.grey : theme.colorScheme.primary),
                    ),
                    title: Text(n.title, style: TextStyle(
                      fontWeight: n.read ? FontWeight.normal : FontWeight.w600,
                    )),
                    subtitle: Text(n.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: !n.read
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF6C63FF),
                              shape: BoxShape.circle,
                            ),
                          )
                        : null,
                    onTap: () => _markRead(n),
                  ),
                );
              },
            ),
    );
  }
}
