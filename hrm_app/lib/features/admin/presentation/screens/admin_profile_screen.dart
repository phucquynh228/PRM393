import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hrm_app/features/admin/data/admin_profile_repository.dart';
import 'package:hrm_app/features/admin/presentation/cubit/admin_cubit.dart';
import 'package:hrm_app/features/admin/presentation/screens/admin_profile_section_screen.dart';
import 'package:hrm_app/features/admin/presentation/screens/admin_permissions_screen.dart';
import 'package:hrm_app/features/auth/data/models/login_response.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';
import 'package:hrm_app/shared/presentation/widgets/profile_widgets.dart';

class AdminProfileScreen extends StatelessWidget {
  final LoginResponse loginResponse;
  final AdminCubit cubit;
  final AdminProfileRepository repository;
  final ValueChanged<String> onManageAccounts;
  final VoidCallback onShiftTemplates, onBranches, onLogout;
  final Future<void> Function() onPasswordChanged;
  const AdminProfileScreen({
    super.key,
    required this.loginResponse,
    required this.cubit,
    required this.repository,
    required this.onManageAccounts,
    required this.onShiftTemplates,
    required this.onBranches,
    required this.onLogout,
    required this.onPasswordChanged,
  });

  void _section(BuildContext context, AdminProfileSection section) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => AdminProfileSectionScreen(
            section: section,
            repository: repository,
            onProfileChanged: cubit.load,
            onPasswordChanged: onPasswordChanged,
            onShiftTemplates: onShiftTemplates,
            onBranches: onBranches,
          ),
        ),
      );
  @override
  Widget build(BuildContext context) => BlocBuilder<AdminCubit, AdminState>(
    bloc: cubit,
    builder: (context, state) {
      final user = state.users
          .whereType<Map>()
          .where((u) => '${u['id']}' == '${loginResponse.userId}')
          .firstOrNull;
      final name = user?['name']?.toString() ?? loginResponse.name;
      return Scaffold(
        appBar: AppBar(
          title: const Text('Hồ sơ & quản trị'),
          actions: [
            IconButton(
              tooltip: 'Làm mới hồ sơ',
              onPressed: state.loading ? null : cubit.load,
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
                  if (state.loading) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 16),
                  ],
                  if (state.error != null) ...[
                    InlineNotice(state.error!, error: true),
                    const SizedBox(height: 16),
                  ],
                  ProfileIdentityCard(
                    name: name,
                    phone:
                        user?['phone']?.toString() ?? loginResponse.phone ?? '',
                    role: 'ADMIN',
                  ),
                  const SizedBox(height: 24),
                  ProfileMenuTile(
                    title: 'Thông tin cá nhân',
                    subtitle: 'Họ tên, email và thông tin liên hệ',
                    icon: Icons.person_outline,
                    onTap: () =>
                        _section(context, AdminProfileSection.personal),
                  ),
                  ProfileMenuTile(
                    title: 'Tài khoản và bảo mật',
                    subtitle: 'Thông tin đăng nhập, liên kết và đổi mật khẩu',
                    icon: Icons.lock_outline,
                    onTap: () =>
                        _section(context, AdminProfileSection.security),
                  ),
                  ProfileMenuTile(
                    title: 'Phân quyền hệ thống',
                    subtitle: 'Vai trò Admin, Quản lý và Nhân viên',
                    icon: Icons.admin_panel_settings_outlined,
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (_) => AdminPermissionsScreen(
                          cubit: cubit,
                          onManageRole: onManageAccounts,
                        ),
                      ),
                    ),
                  ),
                  ProfileMenuTile(
                    title: 'Quản lý tài khoản',
                    subtitle:
                        '${state.users.length} tài khoản · tạo tài khoản và hỗ trợ mật khẩu',
                    icon: Icons.manage_accounts_outlined,
                    onTap: () => onManageAccounts(''),
                  ),
                  ProfileMenuTile(
                    title: 'Cấu hình hệ thống',
                    subtitle: 'Nhắc ca, mẫu ca và cấu hình chi nhánh',
                    icon: Icons.settings_outlined,
                    onTap: () =>
                        _section(context, AdminProfileSection.settings),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Đăng xuất'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
