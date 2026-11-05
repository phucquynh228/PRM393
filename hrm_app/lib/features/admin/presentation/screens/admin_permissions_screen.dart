import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hrm_app/features/admin/presentation/cubit/admin_cubit.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';
import 'package:hrm_app/shared/presentation/widgets/status_badge.dart';

class AdminPermissionsScreen extends StatelessWidget {
  final AdminCubit cubit;
  final ValueChanged<String> onManageRole;
  const AdminPermissionsScreen({
    super.key,
    required this.cubit,
    required this.onManageRole,
  });

  static const _permissions = {
    'ADMIN': [
      'Quản lý tài khoản và chi nhánh toàn hệ thống',
      'Quản lý mẫu ca, xem lịch và báo cáo toàn chuỗi',
      'Xử lý hỗ trợ mật khẩu, cấu hình hệ thống',
    ],
    'MANAGER': [
      'Quản lý nhân viên thuộc chi nhánh được phân công',
      'Phân ca, công bố lịch và theo dõi chấm công chi nhánh',
      'Duyệt nghỉ phép, đổi ca, sửa công và gửi thông báo',
    ],
    'STAFF': [
      'Xem lịch được công bố và chấm công cá nhân',
      'Gửi yêu cầu nghỉ, đổi ca hoặc sửa chấm công',
      'Cập nhật hồ sơ, đổi mật khẩu và đọc thông báo cá nhân',
    ],
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Phân quyền hệ thống')),
    body: BlocBuilder<AdminCubit, AdminState>(
      bloc: cubit,
      builder: (context, state) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const InlineNotice(
                'Quyền truy cập được áp dụng theo vai trò và phạm vi chi nhánh của từng tài khoản. Chọn một vai trò để xem các tài khoản đang sử dụng quyền đó.',
              ),
              for (final entry in _permissions.entries) ...[
                const SizedBox(height: 16),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusBadge.fromStatus(entry.key),
                          Text(
                            '${state.users.whereType<Map>().where((u) => u['role'] == entry.key).length} tài khoản',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      for (final permission in entry.value)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle_outline, size: 18),
                              const SizedBox(width: 10),
                              Expanded(child: Text(permission)),
                            ],
                          ),
                        ),
                      TextButton.icon(
                        onPressed: () => onManageRole(entry.key),
                        icon: const Icon(Icons.manage_accounts_outlined),
                        label: const Text('Xem tài khoản thuộc vai trò'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
