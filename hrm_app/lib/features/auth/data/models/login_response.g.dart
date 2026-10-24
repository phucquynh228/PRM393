// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'login_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LoginResponse _$LoginResponseFromJson(Map<String, dynamic> json) =>
    LoginResponse(
      token: json['token'] as String,
      userId: (json['userId'] as num).toInt(),
      name: json['name'] as String,
      role: json['role'] as String,
      tokenType: json['tokenType'] as String? ?? 'Bearer',
    );

Map<String, dynamic> _$LoginResponseToJson(LoginResponse instance) =>
    <String, dynamic>{
      'token': instance.token,
      'userId': instance.userId,
      'name': instance.name,
      'role': instance.role,
      'tokenType': instance.tokenType,
    };
