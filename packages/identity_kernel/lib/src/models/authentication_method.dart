import 'package:equatable/equatable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'authentication_method.freezed.dart';
part 'authentication_method.g.dart';

enum AuthMethodType {
  @JsonValue('phone')
  phone,
  @JsonValue('passkey')
  passkey,
  @JsonValue('totp')
  totp,
  @JsonValue('seed_phrase')
  seedPhrase,
}

@freezed
class AuthenticationMethod with _$AuthenticationMethod {
  const factory AuthenticationMethod({
    required AuthMethodType type,
    required bool isEnabled,
    required DateTime addedAt,
    String? identifier,
  }) = _AuthenticationMethod;

  factory AuthenticationMethod.fromJson(Map<String, dynamic> json) =>
      _$AuthenticationMethodFromJson(json);
}
