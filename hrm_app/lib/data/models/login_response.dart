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
    this.tokenType = 'Bearer',
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    normalized['userId'] = json['userId'] ?? json['id'] ?? json['user_id'] ?? 0;
    normalized['token'] = json['token'] ?? json['accessToken'] ?? '';
    normalized['name'] = json['name'] ?? json['fullName'] ?? '';
    normalized['role'] = json['role'] ?? 'STAFF';
    normalized['tokenType'] = json['tokenType'] ?? 'Bearer';
    return _$LoginResponseFromJson(normalized);
  }

  Map<String, dynamic> toJson() => _$LoginResponseToJson(this);
}
