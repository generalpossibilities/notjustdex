import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:notjustdex_decentralized_chat/notjustdex_decentralized_chat.dart';
import 'chat_client.dart';

class ConversationListPage extends StatefulWidget {
  final ChatClient? chatClient;

  const ConversationListPage({super.key, this.chatClient});

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage> {
  List<ChatConversation> _conversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  void _loadConversations() {
    if (widget.chatClient != null) {
      setState(() {
        _conversations = widget.chatClient!.getConversations();
      });
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _showNewConversationDialog(context),
          ),
        ],
      ),
      body: _conversations.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('No conversations yet',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => _showNewConversationDialog(context),
                    child: const Text('Start a Chat'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _conversations.length,
              itemBuilder: (_, i) {
                final conv = _conversations[i];
                final displayName = conv.participantAddresses
                    .where((a) => a != 'me')
                    .firstOrNull
                    ?.substring(0, 8) ?? 'Unknown';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(displayName[0]),
                  ),
                  title: Text(displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    conv.lastMessage?.content ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        conv.lastMessage != null
                            ? _formatTime(conv.lastMessage!.sentAt)
                            : '',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (conv.unreadCount > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF6C63FF),
                            shape: BoxShape.circle,
                          ),
                          child: Text('${conv.unreadCount}',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white)),
                        ),
                      ],
                    ],
                  ),
                  onTap: () => context.push('/chat/view', extra: conv),
                );
              },
            ),
    );
  }

  void _showNewConversationDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Chat'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Username or Address'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: resolve address from username via chain, create conversation
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}
