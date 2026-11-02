import 'package:hrm_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:hrm_app/features/auth/data/models/login_response.dart';

class LoginUseCase {
  final AuthRepository repository;

  LoginUseCase(this.repository);

  Future<LoginResponse> call(String phone, String password) {
    return repository.login(phone, password);
  }
}
