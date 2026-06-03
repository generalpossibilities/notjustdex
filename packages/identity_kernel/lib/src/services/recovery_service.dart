import 'dart:async';
import '../exceptions.dart';

class RecoveryService {
  final Map<String, String> _recoverySessions = {};
  final Map<String, Timer> _expiryTimers = {};

  Future<String> initiateRecovery(String identityId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    const recoveryCode = 'RECOVERY_SENT';
    _recoverySessions[identityId] = recoveryCode;
    return recoveryCode;
  }

  Future<bool> verifyRecoveryCode(
    String identityId,
    String code,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!_recoverySessions.containsKey(identityId)) {
      throw RecoveryException('No recovery session found');
    }
    return _recoverySessions[identityId] == code;
  }

  Future<void> resetWallet(String identityId, String newMnemonic) async {
    await Future.delayed(const Duration(milliseconds: 500));
    _recoverySessions.remove(identityId);
  }

  void dispose() {
    for (final timer in _expiryTimers.values) {
      timer.cancel();
    }
    _recoverySessions.clear();
    _expiryTimers.clear();
  }
}
