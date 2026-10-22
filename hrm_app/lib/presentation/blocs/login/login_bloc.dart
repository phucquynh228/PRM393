import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_error.dart';
import '../../../domain/usecases/login_usecase.dart';
import '../../../domain/repositories/google_auth_repository.dart';
import 'login_event.dart';
import 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  final LoginUseCase loginUseCase;
  final GoogleAuthRepository? googleAuth;
  String? _pendingGoogleToken;

  LoginBloc({required this.loginUseCase, this.googleAuth})
    : super(LoginInitial()) {
    on<LoginButtonPressed>(_onLoginButtonPressed);
    on<LoginScreenOpened>((event, emit) {
      if (state is LoginSuccess) emit(LoginInitial());
    });
    on<GoogleLoginPressed>(_onGoogleLogin);
    on<GoogleLinkSubmitted>(_onGoogleLink);
    on<GoogleLinkCancelled>((event, emit) {
      if (state is GoogleLinkRequired &&
          !(state as GoogleLinkRequired).submitting) {
        _pendingGoogleToken = null;
        emit(LoginInitial());
      }
    });
    on<GoogleLoginFailed>((event, emit) {
      if (state is! LoginLoading &&
          state is! GoogleLinkRequired &&
          state is! LoginSuccess) {
        emit(LoginFailure(error: event.message));
      }
    });
  }

  Future<void> _onLoginButtonPressed(
    LoginButtonPressed event,
    Emitter<LoginState> emit,
  ) async {
    if (state is LoginLoading ||
        state is GoogleLinkRequired ||
        state is LoginSuccess) {
      return;
    }
    emit(const LoginLoading());
    try {
      final response = await loginUseCase(event.phone, event.password);
      emit(LoginSuccess(loginResponse: response));
    } catch (error) {
      emit(LoginFailure(error: readableApiError(error)));
    }
  }

  Future<void> _onGoogleLogin(
    GoogleLoginPressed event,
    Emitter<LoginState> emit,
  ) async {
    if (state is LoginLoading ||
        state is GoogleLinkRequired ||
        state is LoginSuccess) {
      return;
    }
    emit(const LoginLoading(google: true));
    try {
      final repository = googleAuth;
      if (repository == null) {
        throw Exception('Đăng nhập Google chưa được cấu hình.');
      }
      final token = event.idToken ?? await repository.selectAccount();
      if (token == null) {
        emit(LoginInitial());
        return;
      }
      final result = await repository.login(token);
      if (result.linkRequired) {
        _pendingGoogleToken = token;
        emit(GoogleLinkRequired(email: result.email));
      } else if (result.login != null) {
        _pendingGoogleToken = null;
        emit(LoginSuccess(loginResponse: result.login!));
      } else {
        throw Exception('Chưa nhận được phiên đăng nhập từ máy chủ.');
      }
    } catch (e) {
      _pendingGoogleToken = null;
      emit(LoginFailure(error: readableApiError(e)));
    }
  }

  Future<void> _onGoogleLink(
    GoogleLinkSubmitted event,
    Emitter<LoginState> emit,
  ) async {
    final current = state;
    if (current is! GoogleLinkRequired ||
        current.submitting ||
        _pendingGoogleToken == null ||
        googleAuth == null) {
      return;
    }
    emit(GoogleLinkRequired(email: current.email, submitting: true));
    try {
      final login = await googleAuth!.link(
        _pendingGoogleToken!,
        event.phone,
        event.password,
      );
      _pendingGoogleToken = null;
      emit(LoginSuccess(loginResponse: login));
    } catch (e) {
      emit(
        GoogleLinkRequired(email: current.email, error: readableApiError(e)),
      );
    }
  }

  @override
  Future<void> close() {
    _pendingGoogleToken = null;
    return super.close();
  }
}
