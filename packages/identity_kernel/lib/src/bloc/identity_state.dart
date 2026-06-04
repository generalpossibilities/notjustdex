import 'package:freezed_annotation/freezed_annotation.dart';
import '../models/user_identity.dart';

part 'identity_state.freezed.dart';

@freezed
class IdentityState with _$IdentityState {
  const factory IdentityState.initial() = IdentityInitial;

  const factory IdentityState.loading() = IdentityLoading;

  const factory IdentityState.authenticated(UserIdentity identity) =
      IdentityAuthenticated;

  const factory IdentityState.unauthenticated() = IdentityUnauthenticated;

  const factory IdentityState.error(String message) = IdentityError;
}
