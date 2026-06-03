import 'dart:convert';
import 'dart:io';

class AuthClient {
  final String baseUrl;

  AuthClient({this.baseUrl = 'http://localhost:8081'});

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$baseUrl$path');
      final req = await client.postUrl(uri);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(body));
      final res = await req.close();
      final bodyStr = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) throw AuthException(bodyStr);
      return jsonDecode(bodyStr) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> registerPhone(String phoneNumber, String username) =>
      _post('/auth/v1/register/phone', {
        'phone_number': phoneNumber,
        'username': username,
      });

  Future<String> loginPhone(String phoneNumber) async {
    final data = await _post('/auth/v1/login/phone', {
      'phone_number': phoneNumber,
    });
    return data['token'] as String;
  }

  Future<Map<String, dynamic>> beginPasskeyRegister(String userId, String userName) =>
      _post('/auth/v1/passkey/register/begin', {
        'user_id': userId,
        'user_name': userName,
      });

  Future<void> finishPasskeyRegister(String userId, String credentialId, String publicKey) async {
    await _post('/auth/v1/passkey/register/finish', {
      'user_id': userId,
      'credential_id': credentialId,
      'public_key': publicKey,
    });
  }

  Future<Map<String, dynamic>> beginPasskeyAuth(String userId) =>
      _post('/auth/v1/passkey/auth/begin', {
        'user_id': userId,
      });

  Future<String> finishPasskeyAuth(String credentialId, int signCount) async {
    final data = await _post('/auth/v1/passkey/auth/finish', {
      'credential_id': credentialId,
      'sign_count': signCount,
    });
    return data['token'] as String;
  }

  Future<Map<String, dynamic>> createChallenge(String walletAddr) =>
      _post('/auth/v1/wallet/challenge', {
        'wallet_addr': walletAddr,
      });

  Future<String> verifyZKP({
    required String challengeId,
    required String proof,
    required List<String> publicInputs,
  }) async {
    final data = await _post('/auth/v1/wallet/verify', {
      'challenge_id': challengeId,
      'proof': proof,
      'public_inputs': publicInputs,
    });
    return data['token'] as String;
  }

  Future<void> linkWallet(String userId, String walletAddr) async {
    await _post('/auth/v1/wallet/link', {
      'user_id': userId,
      'wallet_addr': walletAddr,
    });
  }

  Future<Map<String, dynamic>> validateToken(String token) =>
      _post('/auth/v1/validate', {
        'token': token,
      });
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => 'AuthException: $message';
}
