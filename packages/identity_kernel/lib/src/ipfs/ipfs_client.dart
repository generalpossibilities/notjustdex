import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
    final request = http.MultipartRequest('POST', Uri.parse(_uploadEndpoint));
    request.headers['Accept'] = 'application/json';
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: fileName ?? 'file',
    ));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode != 200) {
      throw IpfsException('Upload failed: HTTP ${response.statusCode}');
    }

    final json = jsonDecode(response.body.split('\n').first) as Map<String, dynamic>;
    return json['Hash'] as String;
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
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          return response.bodyBytes.toList();
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
}

class IpfsException implements Exception {
  final String message;
  const IpfsException(this.message);
  @override
  String toString() => 'IpfsException: $message';
}
