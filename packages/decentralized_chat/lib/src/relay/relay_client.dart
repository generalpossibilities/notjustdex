import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Envelope sent/received via relay.
class RelayEnvelope {
  final String topic;
  final String senderAddress;
  final Map<String, dynamic> payload;

  const RelayEnvelope({
    required this.topic,
    required this.senderAddress,
    required this.payload,
  });
}

/// A connection to a single relay.
class RelayConnection {
  final String url;
  WebSocketChannel? _channel;
  final StreamController<RelayEnvelope> _messages =
      StreamController<RelayEnvelope>.broadcast();
  bool _connected = false;
  Timer? _reconnectTimer;

  RelayConnection(this.url);

  bool get isConnected => _connected;
  Stream<RelayEnvelope> get messages => _messages.stream;

  Future<void> connect() async {
    if (_connected) return;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      await _channel!.ready;
      _connected = true;

      _channel!.stream.listen(
        (data) {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          if (json['type'] == 'message') {
            _messages.add(RelayEnvelope(
              topic: json['topic'] as String,
              senderAddress: json['sender'] as String,
              payload: json['message'] as Map<String, dynamic>,
            ));
          }
        },
        onError: (_) => _handleDisconnect(),
        onDone: () => _handleDisconnect(),
      );
    } catch (_) {
      _handleDisconnect();
    }
  }

  void subscribe(String topic) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({
      'type': 'subscribe',
      'topic': topic,
    }));
  }

  void publish(String topic, Map<String, dynamic> message) {
    if (_channel == null) return;
    _channel!.sink.add(jsonEncode({
      'type': 'publish',
      'topic': topic,
      'message': message,
    }));
  }

  void _handleDisconnect() {
    _connected = false;
    _channel = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), connect);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _connected = false;
  }
}

/// Multi-relay client that connects to N relays simultaneously.
///
/// Messages published to all relays for redundancy.
/// Incoming messages from any relay are forwarded to a single stream.
class ChatRelayClient {
  final List<RelayConnection> _relays = [];
  final StreamController<RelayEnvelope> _allMessages =
      StreamController<RelayEnvelope>.broadcast();
  final List<StreamSubscription<RelayEnvelope>> _subs = [];
  final Set<String> _subscribedTopics = {};

  Stream<RelayEnvelope> get messages => _allMessages.stream;

  /// Connect to a list of relay URLs.
  Future<void> connect(List<String> urls) async {
    await disconnect();
    for (final url in urls) {
      final relay = RelayConnection(url);
      await relay.connect();
      _relays.add(relay);
      _subs.add(relay.messages.listen(_allMessages.add));
    }
    // Re-subscribe to any previously subscribed topics
    for (final topic in _subscribedTopics) {
      for (final relay in _relays) {
        relay.subscribe(topic);
      }
    }
  }

  /// Subscribe to a topic on all connected relays.
  void subscribe(String topic) {
    _subscribedTopics.add(topic);
    for (final relay in _relays) {
      relay.subscribe(topic);
    }
  }

  /// Unsubscribe from a topic.
  void unsubscribe(String topic) {
    _subscribedTopics.remove(topic);
  }

  /// Publish a message to a topic on all relays.
  void publish(String topic, Map<String, dynamic> message) {
    for (final relay in _relays) {
      relay.publish(topic, message);
    }
  }

  Future<void> disconnect() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    for (final relay in _relays) {
      relay.disconnect();
    }
    _relays.clear();
  }

  bool get isConnected => _relays.any((r) => r.isConnected);
}
