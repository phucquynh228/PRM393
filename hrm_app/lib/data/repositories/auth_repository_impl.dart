import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/services/device_info_service.dart';
import '../../core/utils/error_handler.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../main.dart';
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
      final deviceId = await deviceInfoService.getDeviceId();
      
      final request = LoginRequest(
        phone: phone,
        password: password,
        deviceId: deviceId,
      );

      final response = await apiClient.login(request);
      
      if (response.success == true && response.data != null) {
        final token = response.data!.token;
        await secureStorage.write(key: 'jwt_token', value: token);
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Đăng nhập thất bại');
      }
    } on DioException catch (e) {
      throw Exception(ErrorHandler.parseDioError(e, globalBaseUrl));
    } catch (e) {
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
