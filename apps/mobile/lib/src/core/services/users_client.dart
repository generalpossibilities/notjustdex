import 'dart:convert';
import 'dart:io';

class UsersClient {
  final String baseUrl;

  UsersClient({this.baseUrl = 'http://localhost:8082'});

  Future<Map<String, dynamic>> _get(String path, Map<String, String> query) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
      final req = await client.getUrl(uri);
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) throw UsersException(body);
      return jsonDecode(body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$baseUrl$path');
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
      final res = await req.close();
      final bodyStr = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) throw UsersException(bodyStr);
      return jsonDecode(bodyStr) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> _put(String path, Map<String, dynamic> body) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$baseUrl$path');
      final req = await client.putUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
      final res = await req.close();
      final bodyStr = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) throw UsersException(bodyStr);
      return jsonDecode(bodyStr) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  /// Create a new user (called after phone verification + username selection).
  Future<Map<String, dynamic>> createUser(String phoneNumber, String username, String displayName) =>
      _post('/users/v1/create', {
        'phone_number': phoneNumber,
        'username': username,
        'display_name': displayName,
      });

  /// Get user profile by ID.
  Future<Map<String, dynamic>> getUser(String id) =>
      _get('/users/v1/get', {'id': id});

  /// Update profile (display name min 4 chars).
  Future<Map<String, dynamic>> updateProfile({
    required String userId,
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) =>
      _put('/users/v1/update', {
        'user_id': userId,
        if (displayName != null) 'display_name': displayName,
        if (bio != null) 'bio': bio,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      });

  /// Upload avatar photo (multipart).
  Future<Map<String, dynamic>> uploadAvatar(String userId, String filePath) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$baseUrl/users/v1/avatar');
      final req = await client.postUrl(uri);
      final boundary = '----DexChatsBoundary${DateTime.now().millisecondsSinceEpoch}';
      req.headers.contentType = ContentType('multipart', 'form-data', {'boundary': boundary});

      final file = File(filePath);
      final bytes = await file.readAsBytes();
      final name = file.uri.pathSegments.last;

      req.write('--$boundary\r\n'
          'Content-Disposition: form-data; name="user_id"\r\n\r\n'
          '$userId\r\n'
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="avatar"; filename="$name"\r\n'
          'Content-Type: image/jpeg\r\n\r\n');
      req.add(bytes);
      req.write('\r\n--$boundary--\r\n');

      final res = await req.close();
      final resBody = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) throw UsersException(resBody);
      return jsonDecode(resBody) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  /// Check if a username is available on-chain.
  Future<bool> checkUsername(String username) async {
    final data = await _get('/users/v1/check-username', {'username': username});
    return data['available'] as bool;
  }

  /// Resolve a username to a user profile.
  Future<Map<String, dynamic>> resolveUsername(String username) =>
      _get('/users/v1/resolve', {'username': username});

  /// Get wallet for identity.
  Future<Map<String, dynamic>> getWallet(String identityId) =>
      _get('/users/v1/wallet', {'identity_id': identityId});

  /// Export seed phrase (password gated).
  Future<List<String>> exportSeed(String identityId, String password) async {
    final data = await _post('/users/v1/seed/export', {
      'identity_id': identityId,
      'password': password,
    });
    return (data['seed_phrase'] as List).cast<String>();
  }

  /// Rotate seed phrase.
  Future<List<String>> rotateSeed(String identityId) async {
    final data = await _post('/users/v1/seed/rotate', {
      'identity_id': identityId,
    });
    return (data['seed_phrase'] as List).cast<String>();
  }
}

class UsersException implements Exception {
  final String message;
  UsersException(this.message);
  @override
  String toString() => 'UsersException: $message';
}
