import 'package:dio/dio.dart';

class ErrorHandler {
  static String parseDioError(DioException e, String baseUrl) {
    if (e.response?.data != null && e.response?.data is Map) {
      final message = e.response?.data['message'];
      if (message != null && message.toString().isNotEmpty) {
        return message.toString();
      }
    }

    final errStr = e.toString().toLowerCase();
    final isSocketErr = e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        errStr.contains('socketexception') ||
        errStr.contains('connection refused') ||
        errStr.contains('network is unreachable');

    if (isSocketErr) {
      return 'Lỗi kết nối Socket ($baseUrl).\nVui lòng kiểm tra backend server đã được chạy ở port 8080 chưa.';
    }

    if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
      return 'Phiên đăng nhập hết hạn hoặc không có quyền truy cập.';
    }

    return e.message ?? 'Đã xảy ra lỗi kết nối ($e)';
  }
}
