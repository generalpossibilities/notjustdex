import 'dart:async';

enum AuthChallenge {
  phone,
  passkey,
  totp,
}

class AuthenticationService {
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;

  Future<bool> authenticateWithPhone(
    String phoneNumber,
    String verificationCode,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _isAuthenticated = verificationCode.length == 6;
    return _isAuthenticated;
  }

  Future<bool> authenticateWithPasskey(String challenge) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _isAuthenticated = true;
    return true;
  }

  Future<bool> authenticateWithTOTP(String code) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _isAuthenticated = code.length == 6;
    return _isAuthenticated;
  }

  Future<String> sendPhoneVerification(String phoneNumber) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return 'verification_sent';
  }

  void logout() {
    _isAuthenticated = false;
  }
}
