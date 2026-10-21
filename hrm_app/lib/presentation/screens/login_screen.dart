import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_theme.dart';
import '../blocs/login/login_bloc.dart';
import '../blocs/login/login_event.dart';
import '../blocs/login/login_state.dart';
import '../widgets/content_widgets.dart';
import 'admin_home_screen.dart';
import 'branch_manager_screen.dart';
import 'home_screen.dart';
import 'employee/staff_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (context.read<LoginBloc>().state is LoginLoading) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<LoginBloc>().add(
      LoginButtonPressed(phone: _phone.text.trim(), password: _password.text),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: BlocConsumer<LoginBloc, LoginState>(
        listener: (context, state) {
          if (state is LoginSuccess) {
            final login = state.loginResponse;
            final Widget screen = switch (login.role.toUpperCase()) {
              'ADMIN' => AdminHomeScreen(loginResponse: login),
              'MANAGER' => BranchManagerScreen(loginResponse: login),
              'STAFF' => StaffScreen(name: login.name),
              _ => HomeScreen(name: login.name),
            };
            Navigator.of(context)
                .pushReplacement(MaterialPageRoute(builder: (_) => screen));
          }
        },
        builder: (context, state) => LayoutBuilder(
          builder: (context, constraints) {
            final busy = state is LoginLoading;
            final wide = constraints.maxWidth >= 900;
            final form = Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySubtle,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  Icons.coffee_outlined,
                                  color: AppColors.primary,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'HRM Cafe',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 36),
                          Text(
                            'Chào mừng trở lại',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Đăng nhập để bắt đầu ngày làm việc.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 28),
                          if (state is LoginFailure) ...[
                            InlineNotice(
                              state.error.replaceFirst('Exception: ', ''),
                              error: true,
                            ),
                            const SizedBox(height: 20),
                          ],
                          TextFormField(
                            controller: _phone,
                            enabled: !busy,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [
                              AutofillHints.telephoneNumber,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Số điện thoại',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: (value) =>
                                !RegExp(r'^[0-9+() -]{8,15}$')
                                    .hasMatch(value?.trim() ?? '')
                                ? 'Nhập số điện thoại hợp lệ'
                                : null,
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _password,
                            enabled: !busy,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Mật khẩu',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _obscure
                                    ? 'Hiện mật khẩu'
                                    : 'Ẩn mật khẩu',
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Vui lòng nhập mật khẩu'
                                : null,
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: busy ? null : _submit,
                            child: busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Đăng nhập'),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Tài khoản được cấp bởi quản lý hoặc quản trị viên.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (kDebugMode) ...[
                            const SizedBox(height: 24),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text(
                                'Tài khoản dùng thử',
                                style: TextStyle(fontSize: 13),
                              ),
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final demo in [
                                      ('Nhân viên', '0901000003'),
                                      ('Quản lý', '0901000002'),
                                      ('Admin', '0901000001'),
                                    ])
                                      OutlinedButton(
                                        onPressed: busy
                                            ? null
                                            : () {
                                                _phone.text = demo.$2;
                                                _password.text = '123456';
                                              },
                                        child: Text(demo.$1),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
            return Row(
              children: [
                if (wide)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(48),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.coffee_outlined,
                            size: 52,
                            color: AppColors.amberBadge,
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'Một đội ngũ.\nMột nhịp làm việc.',
                            style: TextStyle(
                              fontSize: 38,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Lịch làm rõ ràng. Chấm công thuận tiện.\nQuản lý quán mỗi ngày, ngay trong tầm tay.',
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.7,
                              color: Colors.white.withValues(alpha: .8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(child: form),
              ],
            );
          },
        ),
      ),
    ),
  );
}
