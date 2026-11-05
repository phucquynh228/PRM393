import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:hrm_app/features/auth/data/models/login_response.dart';
import 'package:hrm_app/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:hrm_app/features/branch/presentation/cubit/branch_cubit.dart';
import 'package:hrm_app/shared/presentation/dialogs/account_profile_form.dart';
import 'package:hrm_app/shared/presentation/screens/employee_profile_section_screen.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';
import 'package:hrm_app/shared/presentation/widgets/employee_profile_menu.dart';

class ManagerProfileScreen extends StatefulWidget {
  final LoginResponse loginResponse;
  final BranchCubit cubit;
  final VoidCallback onLogout;
  const ManagerProfileScreen({
    super.key,
    required this.loginResponse,
    required this.cubit,
    required this.onLogout,
  });

  @override
  State<ManagerProfileScreen> createState() => _ManagerProfileScreenState();
}

class _ManagerProfileScreenState extends State<ManagerProfileScreen> {
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() => widget.cubit.fetch('profile', '/manager/profile');

  Map<String, dynamic> _profile(BranchState state) => {
    'id': widget.loginResponse.userId,
    'name': widget.loginResponse.name,
    'phone': widget.loginResponse.phone,
    'role': 'MANAGER',
    'storeName': state.branch['name'],
    'storeCode': state.branch['code'],
    if (state.resources['profile'] is Map)
      ...Map<String, dynamic>.from(state.resources['profile']),
  };

  Future<void> _edit({required bool password}) async {
    final saved = await AccountProfileForm.show(
      context,
      _profile(widget.cubit.state),
      password: password,
      onSave: (data) => widget.cubit.send(
        'PUT',
        password ? '/manager/password' : '/manager/profile',
        data: data,
      ),
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(password ? 'Đã đổi mật khẩu.' : 'Đã cập nhật hồ sơ.'),
      ),
    );
    await _refresh();
    await widget.cubit.fetch('branch', '/manager/branch');
  }

  void _section(EmployeeProfileSection section) => Navigator.of(context)
      .push<void>(
        MaterialPageRoute(
          builder: (_) => BlocBuilder<BranchCubit, BranchState>(
            bloc: widget.cubit,
            builder: (context, state) => EmployeeProfileSectionScreen(
              section: section,
              profile: _profile(state),
              onForgotPassword: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => ForgotPasswordScreen(
                    dio: widget.cubit.dio,
                    initialPhone: '${_profile(state)['phone'] ?? ''}',
                  ),
                ),
              ),
              onEdit:
                  state.loading.contains('profile') ||
                      state.resources['profile'] is! Map
                  ? null
                  : () => _edit(
                      password: section == EmployeeProfileSection.security,
                    ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => BlocBuilder<BranchCubit, BranchState>(
    bloc: widget.cubit,
    builder: (context, state) => Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ cá nhân'),
        actions: [
          IconButton(
            tooltip: 'Làm mới hồ sơ',
            onPressed: state.loading.contains('profile') ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (state.loading.contains('profile')) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                ],
                if (state.errors['profile'] != null) ...[
                  InlineNotice(state.errors['profile']!, error: true),
                  const SizedBox(height: 16),
                ],
                EmployeeProfileMenu(
                  profile: _profile(state),
                  onSection: _section,
                  onLogout: widget.onLogout,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
