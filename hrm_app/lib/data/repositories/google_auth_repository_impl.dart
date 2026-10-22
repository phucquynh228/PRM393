import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/services/device_info_service.dart';
import '../../core/services/google_sign_in_service.dart';
import '../../domain/repositories/google_auth_repository.dart';
import '../models/login_response.dart';

class GoogleAuthRepositoryImpl implements GoogleAuthRepository {
  final Dio dio;
  final GoogleSignInService google;
  final DeviceInfoService device;
  final FlutterSecureStorage storage;
  GoogleAuthRepositoryImpl({
    required this.dio,
    required this.google,
    required this.device,
    required this.storage,
  });

  @override
  Future<String?> selectAccount() => google.selectAccount();

  @override
  Future<GoogleLoginResult> login(String idToken) async {
    final response = await dio.post(
      '/auth/google',
      data: {'idToken': idToken, 'deviceId': await device.getDeviceId()},
    );
    final data = _data(response);
    if (data['linkRequired'] == true) {
      return GoogleLoginResult(
        linkRequired: true,
        email: data['email']?.toString() ?? '',
      );
    }
    final login = await _saveLogin(
      Map<String, dynamic>.from(data['login'] as Map),
    );
    return GoogleLoginResult(
      linkRequired: false,
      email: data['email']?.toString() ?? '',
      login: login,
    );
  }

  @override
  Future<LoginResponse> link(
    String idToken,
    String phone,
    String password,
  ) async {
    final response = await dio.post(
      '/auth/google/link',
      data: {
        'idToken': idToken,
        'deviceId': await device.getDeviceId(),
        'phone': phone.trim(),
        'password': password,
      },
    );
    return _saveLogin(_data(response));
  }

  Map<String, dynamic> _data(Response<dynamic> response) {
    final body = response.data;
    if (body is! Map || body['success'] != true || body['data'] is! Map) {
      throw Exception(
        body is Map
            ? body['message'] ?? 'Đăng nhập Google thất bại'
            : 'Phản hồi không hợp lệ',
      );
    }
    return Map<String, dynamic>.from(body['data'] as Map);
  }

  Future<LoginResponse> _saveLogin(Map<String, dynamic> data) async {
    final login = LoginResponse.fromJson(data);
    if (login.token.isEmpty) {
      throw Exception('Máy chủ chưa cấp phiên đăng nhập.');
    }
    await storage.write(key: 'jwt_token', value: login.token);
    return login;
  }
}
