import 'package:dio/dio.dart';
import 'package:hrm_app/core/config/api_config.dart';

class AdminProfileRepository {
  final Dio dio;
  AdminProfileRepository(this.dio);

  Future<Map<String, dynamic>> call(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    final response = await dio.request(
      '$globalBaseUrl/admin/$path',
      data: data,
      options: Options(method: data == null ? 'GET' : 'PUT'),
    );
    final body = response.data as Map;
    if (body['success'] != true) {
      throw Exception(body['message'] ?? 'Không lưu được thay đổi');
    }
    return Map<String, dynamic>.from(body['data'] as Map? ?? {});
  }
}
