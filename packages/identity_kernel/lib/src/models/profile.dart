import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

@freezed
class Profile with _$Profile {
  const factory Profile({
    required String displayName,
    required String username,
    @Default('') String bio,

    /// IPFS content identifier for avatar image
    String? avatarCid,

    /// IPFS content identifier for cover image
    String? coverCid,

    /// Legacy URL-based avatar (fallback)
    @Default('') String avatarUrl,

    /// Legacy URL-based cover (fallback)
    @Default('') String coverUrl,

    /// When the profile was first created
    DateTime? joinedAt,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
}
