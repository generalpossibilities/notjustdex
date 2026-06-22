import 'package:freezed_annotation/freezed_annotation.dart';
import 'authentication_method.dart';
import 'profile.dart';
import 'username.dart';
import 'wallet.dart';

part 'user_identity.freezed.dart';
part 'user_identity.g.dart';

@freezed
class UserIdentity with _$UserIdentity {
  const factory UserIdentity({
    required String id,
    @UsernameConverter() required Username username,
    required Profile profile,
    required Wallet wallet,
    required List<AuthenticationMethod> authMethods,

    required DateTime createdAt,
    DateTime? lastLoginAt,
  }) = _UserIdentity;

  factory UserIdentity.fromJson(Map<String, dynamic> json) =>
      _$UserIdentityFromJson(json);
}
