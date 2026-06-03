import 'dart:convert';

class JsApiResponse {
  final bool success;
  final dynamic data;
  final String? error;

  const JsApiResponse({required this.success, this.data, this.error});

  String toJson() => jsonEncode({
        'success': success,
        if (data != null) 'data': data,
        if (error != null) 'error': error,
      });
}
