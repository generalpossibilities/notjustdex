import 'package:flutter/material.dart';
import 'browser_page.dart';

/// Opens a URL in an in-app browser modal bottom sheet.
class WebViewSheet {
  static Future<Map<String, String>?> show(
    BuildContext context, {
    required String url,
    String? title,
  }) {
    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.92,
        child: BrowserPage(initialUrl: url, title: title),
      ),
    );
  }
}
