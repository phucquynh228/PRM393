import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInService {
  final Dio dio;
  Future<void>? _sdkInitialization;
  GoogleSignInService(this.dio);

  static const notConfigured =
      'Đăng nhập Google chưa được cấu hình. Vui lòng đăng nhập bằng số điện thoại.';
  static const providerUnavailable =
      'Dịch vụ Google trên thiết bị chưa sẵn sàng. Vui lòng cập nhật Google Play services và đăng nhập tài khoản Google trong Cài đặt. Nếu dùng máy giả lập, hãy chọn bản có Google Play.';

  Future<void> initialize() async {
    if (_sdkInitialization != null) return _sdkInitialization;
    if (!kIsWeb &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      throw Exception(
        'Đăng nhập Google hỗ trợ Android, iOS và trình duyệt web.',
      );
    }
    const configured = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    String clientId = configured.trim();
    if (clientId.isEmpty) {
      final response = await dio.get('/auth/google/config');
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      if (body is! Map ||
          body['success'] != true ||
          data is! Map ||
          data['enabled'] != true) {
        throw Exception(notConfigured);
      }
      clientId = data['clientId']?.toString().trim() ?? '';
    }
    if (!RegExp(r'^[0-9]+-[A-Za-z0-9_-]+\.apps\.googleusercontent\.com$')
        .hasMatch(clientId)) {
      throw Exception(notConfigured);
    }
    const iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
    // Initialize Google's singleton exactly once. No Google SDK work is needed
    // before a valid configuration has been received from our backend.
    _sdkInitialization ??= GoogleSignIn.instance.initialize(
      clientId: kIsWeb
          ? clientId
          : iosClientId.isEmpty
          ? null
          : iosClientId,
      serverClientId: kIsWeb ? null : clientId,
    );
    await _sdkInitialization;
  }

  Future<String?> selectAccount() async {
    try {
      await initialize();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw Exception(
          'Vui lòng dùng nút Google trên trình duyệt để chọn tài khoản.',
        );
      }
      try {
        await GoogleSignIn.instance.signOut();
      } on PlatformException catch (e) {
        // Credential Manager may be unable to clear a previous session (even
        // on the first login). Let authenticate report whether sign-in itself
        // is available; clearing cached state is only a best-effort step.
        if (e.code != 'Clear Failed') rethrow;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw Exception(
          'Chưa nhận được xác thực Google. Vui lòng chọn lại tài khoản.',
        );
      }
      return token;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw Exception(googleSignInError(e));
    } on PlatformException catch (e) {
      throw Exception(googleSignInError(e));
    }
  }
}

String googleSignInError(Object error) {
  if (error is GoogleSignInException) {
    return switch (error.code) {
      GoogleSignInExceptionCode.clientConfigurationError => 'Đăng nhập Google chưa được cấu hình đúng. Vui lòng liên hệ quản trị viên.',
      GoogleSignInExceptionCode.providerConfigurationError =>
        GoogleSignInService.providerUnavailable,
      GoogleSignInExceptionCode.interrupted ||
      GoogleSignInExceptionCode.uiUnavailable =>
        'Quá trình chọn tài khoản Google bị gián đoạn. Vui lòng thử lại.',
      _ => 'Chưa thể đăng nhập Google. Vui lòng thử lại.',
    };
  }
  if (error is PlatformException) {
    if (error.code == 'Clear Failed' ||
        (error.message?.contains('no provider dependencies found') ?? false)) {
      return GoogleSignInService.providerUnavailable;
    }
    return 'Chưa thể mở đăng nhập Google. Vui lòng thử lại.';
  }
  return error.toString().replaceFirst('Exception: ', '');
}
