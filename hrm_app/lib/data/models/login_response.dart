import 'package:json_annotation/json_annotation.dart';

part 'login_response.g.dart';

@JsonSerializable()
class LoginResponse {
  final String token;
  final int userId;
  final String name;
  final String role;
  
  @JsonKey(name: 'tokenType', defaultValue: 'Bearer')
  final String? tokenType;

  LoginResponse({
    required this.token,
    required this.userId,
    required this.name,
    required this.role,
    this.tokenType,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseFromJson(json);

  Map<String, dynamic> toJson() => _$LoginResponseToJson(this);
}
