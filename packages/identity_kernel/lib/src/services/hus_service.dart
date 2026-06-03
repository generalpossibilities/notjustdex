import 'dart:async';

enum HusVerificationLevel { none, pending, basic, verified }

class HusVerification {
  final HusVerificationLevel level;
  final double score;
  final bool isVerified;
  final DateTime? verifiedAt;
  final String? challenge;

  const HusVerification({
    this.level = HusVerificationLevel.none,
    this.score = 0.0,
    this.isVerified = false,
    this.verifiedAt,
    this.challenge,
  });
}

class HusService {
  Future<HusVerification> getStatus(String identityId) async {
    return const HusVerification(
      level: HusVerificationLevel.none,
      score: 0.0,
      isVerified: false,
    );
  }

  Future<String> initiateVerification(
    String identityId,
    String appId,
  ) async {
    return 'hus_challenge_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<HusVerification> submitProof({
    required String identityId,
    required String appId,
    required List<double> projection,
    required List<int> proof,
  }) async {
    return const HusVerification(
      level: HusVerificationLevel.basic,
      score: 85.0,
      isVerified: true,
    );
  }

  Future<double> getScore(String identityId) async {
    return 0.0;
  }

  Stream<HusVerification> watchStatus(String identityId) {
    return Stream.periodic(
      const Duration(seconds: 30),
      (_) => const HusVerification(),
    );
  }
}
