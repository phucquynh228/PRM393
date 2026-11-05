import 'package:flutter/material.dart';
import 'package:hrm_app/shared/presentation/screens/employee_profile_section_screen.dart';
import 'package:hrm_app/shared/presentation/widgets/profile_widgets.dart';

class EmployeeProfileMenu extends StatelessWidget {
  final Map<String, dynamic> profile;
  final ValueChanged<EmployeeProfileSection> onSection;
  final VoidCallback onLogout;
  const EmployeeProfileMenu({
    super.key,
    required this.profile,
    required this.onSection,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ProfileIdentityCard(
        name: '${profile['name'] ?? 'Chưa cập nhật'}',
        phone: '${profile['phone'] ?? 'Chưa cập nhật SĐT'}',
        role: '${profile['role'] ?? 'STAFF'}',
      ),
      const SizedBox(height: 24),
      ProfileMenuTile(
        title: 'Thông tin cá nhân',
        subtitle: 'Họ tên, email và thông tin liên hệ',
        icon: Icons.person_outline,
        onTap: () => onSection(EmployeeProfileSection.personal),
      ),
      ProfileMenuTile(
        title: 'Tài khoản và bảo mật',
        subtitle: 'Thông tin đăng nhập và đổi mật khẩu',
        icon: Icons.lock_outline,
        onTap: () => onSection(EmployeeProfileSection.security),
      ),
      ProfileMenuTile(
        title: 'Thông tin công việc',
        subtitle: 'Chi nhánh, chức vụ và lịch làm mặc định',
        icon: Icons.badge_outlined,
        onTap: () => onSection(EmployeeProfileSection.work),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: onLogout,
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Đăng xuất'),
      ),
    ],
  );
}
