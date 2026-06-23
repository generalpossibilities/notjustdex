import 'dart:async';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A single relay client connection.
class RelayClient {
  final WebSocketChannel channel;
  final Set<String> topics = {};

  RelayClient(this.channel);

  void send(Map<String, dynamic> message) {
    channel.sink.add(jsonEncode(message));
  }
}

/// In-memory pub/sub relay server.
///
/// Topics are conversation IDs. Clients subscribe to topics and receive
/// messages published to those topics. No message storage — purely a
/// real-time forwarder. Anyone can run this server.
class RelayServer {
  final List<RelayClient> _clients = [];
  final Map<String, Set<RelayClient>> _topicSubs = {};
  Timer? _healthTimer;

  /// Create the shelf handler for WebSocket upgrade at `/ws`.
  Handler get handler => webSocketHandler(_handleConnection);

  /// Health check handler: returns 200 if server is running.
  Handler get healthHandler => (Request request) async {
    return Response.ok(
      jsonEncode({
        'status': 'ok',
        'clients': _clients.length,
        'topics': _topicSubs.length,
      }),
      headers: {'content-type': 'application/json'},
    );
  };

  void _handleConnection(WebSocketChannel channel) {
    final client = RelayClient(channel);
    _clients.add(client);

    channel.stream.listen(
      (data) {
        try {
          final msg = jsonDecode(data as String) as Map<String, dynamic>;
          _routeMessage(client, msg);
        } catch (_) {
          client.send({'type': 'error', 'message': 'invalid JSON'});
        }
      },
      onError: (_) => _removeClient(client),
      onDone: () => _removeClient(client),
    );
  }

  void _routeMessage(RelayClient sender, Map<String, dynamic> msg) {
    final type = msg['type'] as String?;

    switch (type) {
      case 'subscribe':
        final topic = msg['topic'] as String?;
        if (topic == null) return;
        sender.topics.add(topic);
        _topicSubs.putIfAbsent(topic, () => {}).add(sender);

      case 'publish':
        final topic = msg['topic'] as String?;
        final message = msg['message'] as Map<String, dynamic>?;
        if (topic == null || message == null) return;

        final envelope = {
          'type': 'message',
          'topic': topic,
          'message': message,
        };
        // Broadcast to all subscribers of this topic (except sender)
        final subs = _topicSubs[topic];
        if (subs != null) {
          for (final client in subs) {
            if (client != sender) {
              client.send(envelope);
            }
          }
        }
    }
  }

  void _removeClient(RelayClient client) {
    _clients.remove(client);
    for (final topic in client.topics) {
      _topicSubs[topic]?.remove(client);
      if (_topicSubs[topic]?.isEmpty == true) {
        _topicSubs.remove(topic);
      }
    }
  }

  void dispose() {
    _healthTimer?.cancel();
    for (final client in _clients.toList()) {
      client.channel.sink.close();
    }
    _clients.clear();
    _topicSubs.clear();
  }
}
