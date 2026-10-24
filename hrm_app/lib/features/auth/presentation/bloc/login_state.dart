import 'package:equatable/equatable.dart';

import 'package:hrm_app/features/auth/data/models/login_response.dart';

abstract class LoginState extends Equatable {
  const LoginState();

  @override
  List<Object> get props => [];
}

class LoginInitial extends LoginState {}

class LoginLoading extends LoginState {
  final bool google;
  const LoginLoading({this.google = false});
  @override
  List<Object> get props => [google];
}

class GoogleLinkRequired extends LoginState {
  final String email;
  final bool submitting;
  final String? error;
  const GoogleLinkRequired({
    required this.email,
    this.submitting = false,
    this.error,
  });
  @override
  List<Object> get props => [email, submitting, error ?? ''];
}

class LoginSuccess extends LoginState {
  final LoginResponse loginResponse;

  const LoginSuccess({required this.loginResponse});

  @override
  List<Object> get props => [loginResponse];
}

class LoginFailure extends LoginState {
  final String error;

  const LoginFailure({required this.error});

  @override
  List<Object> get props => [error];
}
