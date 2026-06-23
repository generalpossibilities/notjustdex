enum AutoLockDuration {
  seconds30,
  minutes1,
  minutes5,
  minutes15,
  never;

  String get displayName {
    switch (this) {
      case AutoLockDuration.seconds30:
        return '30 seconds';
      case AutoLockDuration.minutes1:
        return '1 minute';
      case AutoLockDuration.minutes5:
        return '5 minutes';
      case AutoLockDuration.minutes15:
        return '15 minutes';
      case AutoLockDuration.never:
        return 'Never';
    }
  }

  int get inMilliseconds {
    switch (this) {
      case AutoLockDuration.seconds30:
        return 30000;
      case AutoLockDuration.minutes1:
        return 60000;
      case AutoLockDuration.minutes5:
        return 300000;
      case AutoLockDuration.minutes15:
        return 900000;
      case AutoLockDuration.never:
        return -1;
    }
  }
}

class VaultConfig {
  final AutoLockDuration autoLockDuration;
  final bool biometricRequired;
  final int clipboardClearSeconds;

  const VaultConfig({
    this.autoLockDuration = AutoLockDuration.minutes5,
    this.biometricRequired = true,
    this.clipboardClearSeconds = 30,
  });

  VaultConfig copyWith({
    AutoLockDuration? autoLockDuration,
    bool? biometricRequired,
    int? clipboardClearSeconds,
  }) {
    return VaultConfig(
      autoLockDuration: autoLockDuration ?? this.autoLockDuration,
      biometricRequired: biometricRequired ?? this.biometricRequired,
      clipboardClearSeconds: clipboardClearSeconds ?? this.clipboardClearSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
        'autoLockDuration': autoLockDuration.name,
        'biometricRequired': biometricRequired,
        'clipboardClearSeconds': clipboardClearSeconds,
      };

  factory VaultConfig.fromJson(Map<String, dynamic> json) => VaultConfig(
        autoLockDuration: AutoLockDuration.values.firstWhere(
          (e) => e.name == json['autoLockDuration'],
          orElse: () => AutoLockDuration.minutes5,
        ),
        biometricRequired: json['biometricRequired'] as bool? ?? true,
        clipboardClearSeconds: json['clipboardClearSeconds'] as int? ?? 30,
      );
}
