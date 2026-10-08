import '../../data/models/login_response.dart';

abstract class AuthRepository {
  Future<LoginResponse> login(String phone, String password);
  Future<void> logout();
  Future<bool> isLoggedIn();
}
