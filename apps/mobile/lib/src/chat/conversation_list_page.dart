import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ConversationListPage extends StatefulWidget {
  const ConversationListPage({super.key});

  @override
  State<ConversationListPage> createState() => _ConversationListPageState();
}

class _ConversationListPageState extends State<ConversationListPage> {
  final _conversations = <Map<String, dynamic>>[
    {
      'id': 'conv_1',
      'name': 'Alice',
      'last_message': 'Hey, how are you?',
      'time': '2m ago',
      'unread': 2,
    },
    {
      'id': 'conv_2',
      'name': 'DexChats Dev Team',
      'last_message': 'Welcome to DexChats! 🎉',
      'time': '5m ago',
      'unread': 0,
    },
  ];

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
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(conv['name'][0]),
                  ),
                  title: Text(conv['name'],
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(conv['last_message'],
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(conv['time'],
                          style: theme.textTheme.bodySmall),
                      if (conv['unread'] > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF6C63FF),
                            shape: BoxShape.circle,
                          ),
                          child: Text('${conv['unread']}',
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Chat'),
        content: const TextField(
          decoration: InputDecoration(labelText: 'Username'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Start')),
        ],
      ),
    );
  }
}
