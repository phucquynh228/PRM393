import 'package:equatable/equatable.dart';

abstract class LoginEvent extends Equatable {
  const LoginEvent();

  @override
  List<Object> get props => [];
}

class LoginButtonPressed extends LoginEvent {
  final String phone;
  final String password;

  const LoginButtonPressed({
    required this.phone,
    required this.password,
  });

  @override
  List<Object> get props => [phone, password];
}
