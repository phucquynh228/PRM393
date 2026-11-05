import 'package:flutter/material.dart';

import 'package:hrm_app/features/schedule/presentation/widgets/fixed_roster_editor.dart';
import 'package:hrm_app/shared/presentation/screens/profile_screen.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';

enum EmployeeProfileSection { personal, security, work }

class EmployeeProfileSectionScreen extends StatelessWidget {
  final EmployeeProfileSection section;
  final Map<String, dynamic> profile;
  final VoidCallback? onEdit;
  final VoidCallback? onForgotPassword;
  const EmployeeProfileSectionScreen({
    super.key,
    required this.section,
    required this.profile,
    this.onEdit,
    this.onForgotPassword,
  });

  @override
  Widget build(BuildContext context) {
    final personal = section == EmployeeProfileSection.personal;
    final security = section == EmployeeProfileSection.security;
    return ProfileScreen(
      title: personal
          ? 'Thông tin cá nhân'
          : security
          ? 'Tài khoản và bảo mật'
          : 'Thông tin công việc',
      name: '${profile['name'] ?? 'Chưa cập nhật'}',
      role: '${profile['role'] ?? 'STAFF'}',
      details: personal
          ? {
              'Họ và tên': profile['name'],
              'Email': profile['email'],
              'Liên hệ khẩn cấp': profile['emergencyContact'],
              'Địa chỉ': profile['address'],
            }
          : security
          ? {
              'Mã tài khoản': profile['id'],
              'Số điện thoại đăng nhập': profile['phone'],
            }
          : {
              'Mã nhân viên': profile['employeeCode'],
              'Chi nhánh': profile['storeName'],
              'Mã chi nhánh': profile['storeCode'],
              'Trạng thái làm việc': switch (profile['employmentStatus']) {
                'ACTIVE' => 'Đang làm việc',
                'WAITING_TRANSFER' => 'Chờ điều chuyển',
                'INACTIVE' => 'Ngừng làm việc',
                _ => null,
              },
            },
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (security) ...[
            Text(
              'Đổi mật khẩu',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text('Bạn có thể tự đổi mật khẩu bằng mật khẩu hiện tại.'),
            const SizedBox(height: 16),
          ],
          if (!personal && !security) ...[
            FixedRosterSummary(entries: profile['fixedRoster']),
            const SizedBox(height: 16),
            const InlineNotice(
              'Chức vụ, chi nhánh và lịch làm mặc định do người có quyền quản lý cập nhật.',
            ),
          ] else
            FilledButton.icon(
              onPressed: onEdit,
              icon: Icon(security ? Icons.lock_outline : Icons.edit_outlined),
              label: Text(security ? 'Đổi mật khẩu' : 'Cập nhật thông tin'),
            ),
          if (security) ...[
            const Divider(height: 32),
            Text(
              'Quên mật khẩu?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Nếu không nhớ mật khẩu hiện tại, hãy gửi yêu cầu để Admin xác minh danh tính và hỗ trợ đặt lại mật khẩu.',
            ),
            if (onForgotPassword != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onForgotPassword,
                icon: const Icon(Icons.support_agent),
                label: const Text('Yêu cầu Admin hỗ trợ'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
