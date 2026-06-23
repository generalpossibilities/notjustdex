import 'dart:async';
import 'package:flutter/material.dart';
import 'package:notjustdex_decentralized_chat/notjustdex_decentralized_chat.dart';
import 'chat_client.dart';

class ChatViewPage extends StatefulWidget {
  final ChatConversation conversation;
  final ChatClient? chatClient;

  const ChatViewPage({
    super.key,
    required this.conversation,
    this.chatClient,
  });

  @override
  State<ChatViewPage> createState() => _ChatViewPageState();
}

class _ChatViewPageState extends State<ChatViewPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<ChatMessage> _messages = [];
  StreamSubscription<ChatMessage>? _sub;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _sub = widget.chatClient?.messages.listen(_onNewMessage);
  }

  void _loadMessages() {
    if (widget.chatClient == null) return;
    setState(() {
      _messages = widget.chatClient!.getMessages(widget.conversation.id);
    });
  }

  void _onNewMessage(ChatMessage msg) {
    if (msg.conversationId != widget.conversation.id) return;
    setState(() {
      _messages.add(msg);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _sub?.cancel();
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.chatClient?.sendMessage(widget.conversation.id, text);
    _controller.clear();
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = widget.conversation.participantAddresses
        .where((a) => a != 'me')
        .firstOrNull
        ?.substring(0, 8) ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(displayName[0], style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: const TextStyle(fontSize: 16)),
                Text(
                  widget.chatClient != null ? 'connected' : 'offline',
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.chatClient != null
                        ? Colors.green
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text(
                      'No messages yet. Start the conversation!',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg = _messages[i];
                      return Align(
                        alignment: msg.isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: msg.isMe
                                ? theme.colorScheme.primary
                                : theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: msg.isMe
                                  ? const Radius.circular(16)
                                  : Radius.zero,
                              bottomRight: msg.isMe
                                  ? Radius.zero
                                  : const Radius.circular(16),
                            ),
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          child: Column(
                            crossAxisAlignment: msg.isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.content,
                                style: TextStyle(
                                  color: msg.isMe ? Colors.white : null,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatTime(msg.sentAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: msg.isMe
                                      ? Colors.white70
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(
                    color: theme.colorScheme.surfaceContainerHighest),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: () {},
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Message',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: theme.colorScheme.primary,
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
