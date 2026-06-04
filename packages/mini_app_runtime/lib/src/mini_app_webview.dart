import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'models/mini_app.dart';
import 'models/permission.dart';
import 'bridge/js_bridge.dart';

class MiniAppWebView extends StatefulWidget {
  final MiniApp app;
  final DexChatsJsBridge bridge;

  const MiniAppWebView({
    super.key,
    required this.app,
    required this.bridge,
  });

  @override
  State<MiniAppWebView> createState() => _MiniAppWebViewState();
}

class _MiniAppWebViewState extends State<MiniAppWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'DexChatsBridge',
        onMessageReceived: (message) {
          final response = widget.bridge.handleCall(message.message);
          _controller.runJavaScript(
            'window.dispatchEvent(new MessageEvent("message", {data: $response}));',
          );
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => _progress = progress / 100);
          },
          onPageFinished: (_) {
            if (!mounted) return;
            _controller.runJavaScript(widget.bridge.getBridgeInjection());
            setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            if (request.url.startsWith('dexchats://')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.app.entryUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.app.name),
        actions: [
          if (_isLoading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(value: _progress),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}

class PermissionRequestDialog extends StatelessWidget {
  final MiniApp app;

  const PermissionRequestDialog({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.apps, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('${app.name} needs permissions',
                style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Allow "${app.name}" to:', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          ...app.requiredPermissions.map((perm) {
            if (perm == MiniAppPermission.none) return const SizedBox();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(_permissionIcon(perm), size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      permissionLabels[perm] ?? perm.name,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Deny'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Allow'),
        ),
      ],
    );
  }

  IconData _permissionIcon(MiniAppPermission perm) {
    return switch (perm) {
      MiniAppPermission.identity => Icons.person,
      MiniAppPermission.wallet => Icons.account_balance_wallet,
      MiniAppPermission.payments => Icons.payment,
      MiniAppPermission.camera => Icons.camera_alt,
      MiniAppPermission.microphone => Icons.mic,
      MiniAppPermission.location => Icons.location_on,
      MiniAppPermission.notifications => Icons.notifications,
      MiniAppPermission.contacts => Icons.contacts,
      MiniAppPermission.none => Icons.help,
    };
  }
}
