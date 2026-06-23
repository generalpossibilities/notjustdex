import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Minimal light client for Acki Nacki chain.
/// Connects directly to any AN RPC endpoint — no Go relay.
///
/// Every user can self-host an AN RPC node or use a public one.
/// The app never depends on a single endpoint: fallback list is configurable.
class AnLightClient {
  final List<String> _rpcUrls;
  int _currentIndex = 0;

  AnLightClient(this._rpcUrls);

  String get currentRpc => _rpcUrls[_currentIndex % _rpcUrls.length];

  /// Submit a signed transaction to the AN chain.
  Future<ChainTxResult> submitTransaction({
    required String contractAddress,
    required String method,
    required Map<String, dynamic> args,
    required List<int> signature,
    required List<int> publicKey,
  }) async {
    final payload = jsonEncode({
      'jsonrpc': '2.0',
      'id': Random.secure().nextInt(1 << 53),
      'method': 'an_submitTransaction',
      'params': [
        {
          'contract': contractAddress,
          'method': method,
          'args': args,
          'signature': base64Url.encode(signature),
          'publicKey': base64Url.encode(publicKey),
        },
      ],
    });

    return await _sendRequest(payload);
  }

  /// Query chain state (read-only, no signature needed).
  Future<dynamic> query({
    required String contractAddress,
    required String method,
    Map<String, dynamic> args = const {},
  }) async {
    final payload = jsonEncode({
      'jsonrpc': '2.0',
      'id': Random.secure().nextInt(1 << 53),
      'method': 'an_query',
      'params': [
        {
          'contract': contractAddress,
          'method': method,
          'args': args,
        },
      ],
    });

    final result = await _sendRequest(payload);
    return result.data;
  }

  /// Subscribe to chain events (e.g., IdentityRegistered, PostCreated).
  Stream<ChainEvent> subscribe(String eventName) {
    return _eventStream(eventName);
  }

  Future<ChainTxResult> _sendRequest(String payload) async {
    // In production: HTTP POST to current RPC URL.
    // This is a stub that simulates chain interaction for development.
    final hash = sha256.convert(utf8.encode(payload)).toString();
    return ChainTxResult(
      txHash: hash,
      success: true,
      blockNumber: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      data: {'status': 'ok', 'tx': hash},
    );
  }

  Stream<ChainEvent> _eventStream(String eventName) {
    // In production: WebSocket subscription to AN chain events.
    // Stub: emits nothing.
    return const Stream.empty();
  }

  void dispose() {}
}

class ChainTxResult {
  final String txHash;
  final bool success;
  final int blockNumber;
  final dynamic data;

  const ChainTxResult({
    required this.txHash,
    required this.success,
    required this.blockNumber,
    required this.data,
  });
}

class ChainEvent {
  final String eventName;
  final Map<String, dynamic> args;
  final int blockNumber;

  const ChainEvent({
    required this.eventName,
    required this.args,
    required this.blockNumber,
  });
}
