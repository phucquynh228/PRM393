import '../../data/models/login_response.dart';

class GoogleLoginResult {
  final bool linkRequired;
  final String email;
  final LoginResponse? login;
  const GoogleLoginResult({
    required this.linkRequired,
    required this.email,
    this.login,
  });
}

abstract class GoogleAuthRepository {
  Future<String?> selectAccount();
  Future<GoogleLoginResult> login(String idToken);
  Future<LoginResponse> link(String idToken, String phone, String password);
}
