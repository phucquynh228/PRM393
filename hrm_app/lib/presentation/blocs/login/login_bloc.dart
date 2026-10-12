import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/login_usecase.dart';
import 'login_event.dart';
import 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final LoginUseCase loginUseCase;

  LoginBloc({required this.loginUseCase}) : super(LoginInitial()) {
    on<LoginButtonPressed>(_onLoginButtonPressed);
  }

  Future<void> _onLoginButtonPressed(
    LoginButtonPressed event,
    Emitter<LoginState> emit,
  ) async {
    emit(LoginLoading());
    try {
      final response = await loginUseCase(event.phone, event.password);
      emit(LoginSuccess(loginResponse: response));
    } catch (error) {
      emit(LoginFailure(error: error.toString()));
    }
  }
}
