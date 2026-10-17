import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/login/login_bloc.dart';
import '../blocs/login/login_event.dart';
import '../blocs/login/login_state.dart';
import 'admin_home_screen.dart';
import 'branch_manager_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  void _onLoginButtonPressed() {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    if (phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đủ SĐT và Mật khẩu')),
      );
      return;
    }
    context.read<LoginBloc>().add(
          LoginButtonPressed(phone: phone, password: password),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocListener<LoginBloc, LoginState>(
        listener: (context, state) {
          if (state is LoginFailure) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Lỗi Đăng Nhập'),
                content: Text(state.error.replaceAll('Exception: ', '')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Đóng'),
                  )
                ],
              ),
            );
          } else if (state is LoginSuccess) {
            final role = state.loginResponse.role.toUpperCase();
            if (role == 'MANAGER') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => BranchManagerScreen(
                    loginResponse: state.loginResponse,
                  ),
                ),
              );
            } else if (role == 'ADMIN') {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => AdminHomeScreen(
                    loginResponse: state.loginResponse,
                  ),
                ),
              );
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            }
          }
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Icon(
                    Icons.local_cafe,
                    size: 100,
                    color: Colors.brown[600],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'HRM Cafe',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown,
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Phone input
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Số điện thoại',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Password input
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Login button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: BlocBuilder<LoginBloc, LoginState>(
                      builder: (context, state) {
                        return ElevatedButton(
                          onPressed: state is LoginLoading
                              ? null
                              : _onLoginButtonPressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.brown[600],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: state is LoginLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  'Đăng Nhập',
                                  style: TextStyle(
                                      fontSize: 18, color: Colors.white),
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
