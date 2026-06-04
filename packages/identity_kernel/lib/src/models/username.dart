import 'package:equatable/equatable.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

class Username extends Equatable {
  final String value;

  const Username._(this.value);

  static const int minLength = 4;
  static const int maxLength = 32;
  static final RegExp _validPattern = RegExp(r'^[a-zA-Z0-9_]+$');

  static Username? tryCreate(String value) {
    final trimmed = value.trim();
    if (trimmed.length < minLength || trimmed.length > maxLength) return null;
    if (!_validPattern.hasMatch(trimmed)) return null;
    return Username._(trimmed.toLowerCase());
  }

  factory Username(String value) {
    final result = tryCreate(value);
    if (result == null) {
      throw ArgumentError('Invalid username: $value');
    }
    return result;
  }

  @override
  List<Object?> get props => [value];

  @override
  String toString() => '@$value';
}

class UsernameConverter implements JsonConverter<Username, String> {
  const UsernameConverter();

  @override
  Username fromJson(String json) => Username(json);

  @override
  String toJson(Username object) => object.value;
}
