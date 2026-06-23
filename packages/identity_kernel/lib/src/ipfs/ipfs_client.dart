import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// IPFS client — upload and fetch content from any IPFS gateway/API.
///
/// No centralized pinning service required. Users can:
///   - Use any public gateway (ipfs.io, cloudflare-ipfs.com, etc.)
///   - Run their own IPFS node and point here
///   - Use a pinning service as convenience (not requirement)
class IpfsClient {
  final List<String> _gateways;
  final String _uploadEndpoint;
  int _gatewayIndex = 0;

  IpfsClient({
    List<String>? gateways,
    String? uploadEndpoint,
  })  : _gateways = gateways ??
            [
              'https://ipfs.io/ipfs/',
              'https://cloudflare-ipfs.com/ipfs/',
              'https://dweb.link/ipfs/',
            ],
        _uploadEndpoint = uploadEndpoint ?? 'https://ipfs.io/api/v0/add';

  /// Upload content bytes to IPFS. Returns CID string.
  Future<String> uploadBytes(List<int> bytes, {String? fileName}) async {
    final client = HttpClient();
    try {
      final boundary = '----${DateTime.now().millisecondsSinceEpoch}';
      final request = await client.postUrl(Uri.parse(_uploadEndpoint));

      request.headers.contentType = ContentType('multipart', 'form-data',
          parameters: {'boundary': boundary});
      request.headers.set('Accept', 'application/json');

      final body = _buildMultipartBody(boundary, bytes, fileName: fileName);
      request.contentLength = body.length;
      request.add(body);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw IpfsException('Upload failed: HTTP ${response.statusCode}');
      }

      final json = jsonDecode(responseBody.split('\n').first) as Map<String, dynamic>;
      return json['Hash'] as String;
    } finally {
      client.close();
    }
  }

  /// Upload a JSON object to IPFS. Returns CID string.
  Future<String> uploadJson(Map<String, dynamic> json) async {
    final bytes = utf8.encode(jsonEncode(json));
    return uploadBytes(bytes, fileName: 'data.json');
  }

  /// Fetch content from IPFS by CID. Returns raw bytes.
  Future<List<int>> fetchBytes(String cid) async {
    for (var i = 0; i < _gateways.length; i++) {
      final url = _gateways[_gatewayIndex % _gateways.length] + cid;
      _gatewayIndex++;
      try {
        final client = HttpClient();
        try {
          final request = await client.getUrl(Uri.parse(url));
          final response = await request.close();
          if (response.statusCode == 200) {
            return await response.fold<List<int>>(
              <int>[],
              (prev, chunk) => prev..addAll(chunk),
            );
          }
        } finally {
          client.close();
        }
      } catch (e) {
        if (i == _gateways.length - 1) rethrow;
      }
    }
    throw IpfsException('All gateways failed for CID: $cid');
  }

  /// Fetch JSON from IPFS.
  Future<Map<String, dynamic>> fetchJson(String cid) async {
    final bytes = await fetchBytes(cid);
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }

  /// Get a gateway URL for direct use (e.g., in Image.network).
  String gatewayUrl(String cid) {
    return _gateways[_gatewayIndex % _gateways.length] + cid;
  }

  List<int> _buildMultipartBody(
    String boundary,
    List<int> bytes, {
    String? fileName,
  }) {
    final header = '--$boundary\r\n'
        'Content-Disposition: form-data; name="file"'
        '${fileName != null ? '; filename="$fileName"' : ''}\r\n'
        'Content-Type: application/octet-stream\r\n\r\n';
    final footer = '\r\n--$boundary--\r\n';

    final headerBytes = utf8.encode(header);
    final footerBytes = utf8.encode(footer);

    return [...headerBytes, ...bytes, ...footerBytes];
  }
}

class IpfsException implements Exception {
  final String message;
  const IpfsException(this.message);
  @override
  String toString() => 'IpfsException: $message';
}
