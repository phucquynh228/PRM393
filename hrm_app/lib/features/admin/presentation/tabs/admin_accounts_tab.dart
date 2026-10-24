import 'package:flutter/material.dart';

import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';
import 'package:hrm_app/shared/presentation/widgets/directory_list.dart';
import 'package:hrm_app/shared/presentation/widgets/status_badge.dart';

class AdminAccountsTab extends StatelessWidget {
  final List<dynamic> users;
  final Future<void> Function() onRefresh;
  final VoidCallback onAddUser;
  final void Function(int userId, String userName) onResetDevice;
  const AdminAccountsTab({
    super.key,
    required this.users,
    required this.onRefresh,
    required this.onAddUser,
    required this.onResetDevice,
  });
  Widget _actions(Map<String, dynamic> user) => PopupMenuButton<String>(
    tooltip: 'Thao tác tài khoản',
    onSelected: (_) => onResetDevice(user['id'], user['name'] ?? 'Nhân viên'),
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'reset', child: Text('Đặt lại liên kết thiết bị')),
    ],
  );
  @override
  Widget build(BuildContext context) => DirectoryList(
    title: 'Tài khoản',
    subtitle: 'Quản lý quyền truy cập và thiết bị của đội ngũ',
    items: users,
    searchFields: const ['name', 'phone', 'storeName'],
    onRefresh: onRefresh,
    filterField: 'role',
    filterOptions: const {
      'STAFF': 'Nhân viên',
      'MANAGER': 'Quản lý',
      'ADMIN': 'Admin',
    },
    action: FilledButton.icon(
      onPressed: onAddUser,
      icon: const Icon(Icons.person_add_outlined),
      label: const Text('Tạo tài khoản'),
    ),
    columns: const [
      'Họ tên',
      'Số điện thoại',
      'Chi nhánh',
      'Vai trò',
      'Thiết bị',
      '',
    ],
    cells: (u) => [
      DataCell(Text(u['name'] ?? '—')),
      DataCell(Text(u['phone'] ?? '—')),
      DataCell(Text(u['storeName'] ?? 'Chưa phân công')),
      DataCell(StatusBadge.fromStatus(u['role'])),
      DataCell(Text(u['deviceId'] == null ? 'Chưa liên kết' : 'Đã liên kết')),
      DataCell(_actions(u)),
    ],
    itemBuilder: (u) => SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            child: Text(
              (u['name']?.toString().isNotEmpty == true)
                  ? u['name'].toString().characters.first
                  : '?',
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u['name'] ?? '—',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  '${u['phone'] ?? '—'} · ${u['storeName'] ?? 'Chưa phân công'}',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusBadge.fromStatus(u['role']),
                    Text(
                      u['deviceId'] == null
                          ? 'Chưa liên kết thiết bị'
                          : 'Đã liên kết thiết bị',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          _actions(u),
        ],
      ),
    ),
  );
}
