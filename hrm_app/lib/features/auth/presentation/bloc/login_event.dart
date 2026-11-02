import 'package:equatable/equatable.dart';

abstract class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object> get props => [];
}

class LoginButtonPressed extends LoginEvent {
  final String phone;
  final String password;

  const LoginButtonPressed({required this.phone, required this.password});

  @override
  List<Object> get props => [phone, password];
}

class GoogleLoginPressed extends LoginEvent {
  // Web receives this token from Google's own rendered button.
  final String? idToken;
  const GoogleLoginPressed({this.idToken});
}

class GoogleLinkSubmitted extends LoginEvent {
  final String phone, password;
  const GoogleLinkSubmitted({required this.phone, required this.password});
}

class GoogleLinkCancelled extends LoginEvent {}

class LoginScreenOpened extends LoginEvent {}

class GoogleLoginFailed extends LoginEvent {
  final String message;
  const GoogleLoginFailed(this.message);
}
