import 'package:dio/dio.dart';

String readableApiError(Object? error) {
  if (error is DioException) {
    final body = error.response?.data;
    if (body is Map && body['message'] != null) {
      return body['message'].toString();
    }
    if (error.response?.statusCode == 401) {
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }
    if (error.response?.statusCode == 403) {
      return 'Tài khoản chưa có quyền thực hiện thao tác này.';
    }
    return 'Chưa kết nối được máy chủ. Vui lòng kiểm tra mạng và thử lại.';
  }
  if (error is FormatException || error is TypeError) {
    return 'Dữ liệu phản hồi chưa hợp lệ. Vui lòng làm mới hoặc liên hệ quản lý.';
  }
  return error.toString().replaceFirst('Exception: ', '');
}
