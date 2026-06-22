import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'js_api.dart';

typedef ApiHandler = JsApiResponse Function(Map<String, dynamic> params);

class NotJustDexJsBridge {
  final Map<String, ApiHandler> _handlers = {};
  final _channel = ValueNotifier<String?>(null);

  NotJustDexJsBridge() {
    registerDefaultHandlers();
  }

  ValueNotifier<String?> get pendingCall => _channel;

  void registerHandler(String method, ApiHandler handler) {
    _handlers[method] = handler;
  }

  String getBridgeInjection() {
    return '''
(function() {
  const api = {};
  const pending = {};

  window.notjustdex = {
    call: function(method, params, callback) {
      const id = 'req_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
      pending[id] = callback;
      window.NotJustDexBridge.postMessage(JSON.stringify({id: id, method: method, params: params || {}}));
    },
    getIdentity: function(cb) { this.call('getIdentity', {}, cb); },
    getWallet: function(cb) { this.call('getWallet', {}, cb); },
    requestPayment: function(to, amount, cb) { this.call('requestPayment', {to: to, amount: amount}, cb); },
    showToast: function(message) { this.call('showToast', {message: message}); },
    shareContent: function(data) { this.call('shareContent', {data: data}); },
  };

  window.addEventListener('message', function(e) {
    try {
      const msg = JSON.parse(e.data);
      if (msg.id && pending[msg.id]) {
        pending[msg.id](msg);
        delete pending[msg.id];
      }
    } catch(_) {}
  });
})();
''';
  }

  String handleCall(String jsonMessage) {
    try {
      final msg = jsonDecode(jsonMessage) as Map<String, dynamic>;
      final id = msg['id'] as String?;
      final method = msg['method'] as String;
      final params = msg['params'] as Map<String, dynamic>? ?? {};

      final handler = _handlers[method];
      if (handler == null) {
        return jsonEncode({
          'id': id,
          'success': false,
          'error': 'Method not found: $method',
        });
      }

      final result = handler(params);
      return jsonEncode({
        'id': id,
        'success': result.success,
        if (result.data != null) 'data': result.data,
        if (result.error != null) 'error': result.error,
      });
    } catch (e) {
      return jsonEncode({
        'success': false,
        'error': e.toString(),
      });
    }
  }

  void registerDefaultHandlers() {
    registerHandler('getIdentity', (params) {
      return const JsApiResponse(
        success: true,
        data: {
          'username': 'user',
          'display_name': 'User',
          'avatar_url': null,
        },
      );
    });

    registerHandler('getWallet', (params) {
      return const JsApiResponse(
        success: true,
        data: {
          'address': '0x...',
          'balance': '0',
          'chain': 'Acki Nacki',
        },
      );
    });

    registerHandler('requestPayment', (params) {
      final to = params['to'] as String?;
      final amount = params['amount'];
      return JsApiResponse(
        success: true,
        data: {
          'tx_hash': 'tx_${DateTime.now().millisecondsSinceEpoch}',
          'to': to,
          'amount': amount,
          'status': 'pending',
        },
      );
    });

    registerHandler('showToast', (params) {
      debugPrint('[MiniApp Toast] ${params['message']}');
      return const JsApiResponse(success: true);
    });

    registerHandler('shareContent', (params) {
      debugPrint('[MiniApp Share] ${params['data']}');
      return const JsApiResponse(success: true);
    });
  }
}
