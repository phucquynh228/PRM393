import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/services/device_info_service.dart';
import '../../domain/repositories/auth_repository.dart';
import '../models/login_request.dart';
import '../models/login_response.dart';
import '../remote/api_client.dart';

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient apiClient;
  final DeviceInfoService deviceInfoService;
  final FlutterSecureStorage secureStorage;

  AuthRepositoryImpl({
    required this.apiClient,
    required this.deviceInfoService,
    required this.secureStorage,
  });

  @override
  Future<LoginResponse> login(String phone, String password) async {
    try {
      debugPrint('>>> [AuthRepo] Getting device ID...');
      final deviceId = await deviceInfoService.getDeviceId();
      debugPrint('>>> [AuthRepo] Device ID: $deviceId');

      final request = LoginRequest(
        phone: phone,
        password: password,
        deviceId: deviceId,
      );

      debugPrint('>>> [AuthRepo] Calling API login...');
      final response = await apiClient.login(request);
      debugPrint('>>> [AuthRepo] API response received: ${response.success}');

      if (response.success == true && response.data != null) {
        final token = response.data!.token;
        await secureStorage.write(key: 'jwt_token', value: token);
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Login failed');
      }
    } on DioException catch (e) {
      if (e.response?.data != null && e.response?.data is Map) {
        final message = e.response?.data['message'];
        if (message != null && message.toString().isNotEmpty) {
          throw Exception(message.toString());
        }
      }
      rethrow;
    } catch (e) {
      debugPrint('>>> [AuthRepo] Exception caught: $e');
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    await secureStorage.delete(key: 'jwt_token');
  }

  @override
  Future<bool> isLoggedIn() async {
    final token = await secureStorage.read(key: 'jwt_token');
    return token != null && token.isNotEmpty;
  }
}
