import 'package:dio/dio.dart';

import 'package:hrm_app/core/config/api_config.dart';

class PasswordSupportRepository {
  final Dio dio;
  PasswordSupportRepository(this.dio);

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
  }) async {
    final response = await dio.request(
      '$globalBaseUrl$path',
      data: data,
      queryParameters: query,
      options: Options(method: method),
    );
    final body = response.data;
    if (body is! Map || body['success'] != true) {
      throw Exception(
        body is Map
            ? body['message'] ?? 'Không xử lý được yêu cầu'
            : 'Dữ liệu phản hồi không hợp lệ',
      );
    }
    return body;
  }

  Future<String> submit({
    required String phone,
    required String name,
    String? note,
  }) async {
    final body = await _request(
      'POST',
      '/auth/password-support',
      data: {'phone': phone, 'name': name, 'note': note},
    );
    return body['message']?.toString() ??
        'Vui lòng gặp trực tiếp Admin để xác minh và nhận hỗ trợ.';
  }

  Future<List<Map<String, dynamic>>> list(String status) async {
    final body = await _request(
      'GET',
      '/admin/password-support',
      query: {'status': status},
    );
    return (body['data'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  Future<void> decide(
    int id, {
    required bool resolve,
    bool identityVerified = false,
    String? password,
    String? note,
  }) async {
    await _request(
      'PUT',
      '/admin/password-support/$id',
      data: {
        'action': resolve ? 'RESOLVE' : 'REJECT',
        'identityVerified': identityVerified,
        if (resolve) 'newPassword': password,
        'adminNote': note,
      },
    );
  }
}
