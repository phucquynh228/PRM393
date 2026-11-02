import 'package:flutter/material.dart';

import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';
import 'package:hrm_app/shared/presentation/widgets/directory_list.dart';
import 'package:hrm_app/shared/presentation/widgets/status_badge.dart';

class AdminAccountsTab extends StatefulWidget {
  final List<dynamic> users;
  final List<dynamic> stores;
  final Future<void> Function() onRefresh;
  final VoidCallback onAddUser;
  final void Function(int userId, String userName) onResetDevice;
  final ValueChanged<Map<String, dynamic>>? onPlacement;
  const AdminAccountsTab({
    super.key,
    required this.users,
    this.stores = const [],
    required this.onRefresh,
    required this.onAddUser,
    required this.onResetDevice,
    this.onPlacement,
  });

  @override
  State<AdminAccountsTab> createState() => _AdminAccountsTabState();
}

class _AdminAccountsTabState extends State<AdminAccountsTab> {
  String _branch = '';

  Map<String, String> get _branches {
    final branches = <String, String>{};
    for (final store in widget.stores.whereType<Map>()) {
      final id = store['id']?.toString();
      if (id == null) continue;
      final code = store['code']?.toString();
      branches[id] =
          '${code == null || code.isEmpty ? '' : '$code · '}'
          '${store['name'] ?? 'Chi nhánh #$id'}';
    }
    for (final user in widget.users.whereType<Map>()) {
      final id = user['storeId']?.toString();
      if (id != null) {
        branches.putIfAbsent(
          id,
          () => user['storeName']?.toString() ?? 'Chi nhánh #$id',
        );
      }
    }
    return branches;
  }

  @override
  void didUpdateWidget(covariant AdminAccountsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_branch.isNotEmpty &&
        _branch != 'unassigned' &&
        !_branches.containsKey(_branch)) {
      _branch = '';
    }
  }

  Widget _actions(Map<String, dynamic> user) => PopupMenuButton<String>(
    tooltip: 'Thao tác tài khoản',
    onSelected: (v) => v == 'placement'
        ? widget.onPlacement?.call(user)
        : widget.onResetDevice(user['id'], user['name'] ?? 'Nhân viên'),
    itemBuilder: (_) => [
      if (user['role'] != 'ADMIN' && widget.onPlacement != null)
        const PopupMenuItem(
          value: 'placement',
          child: Text('Điều chuyển / trạng thái làm việc'),
        ),
      const PopupMenuItem(
        value: 'reset',
        child: Text('Đặt lại liên kết thiết bị'),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => DirectoryList(
    title: 'Tài khoản',
    subtitle: 'Quản lý quyền truy cập và thiết bị của đội ngũ',
    items: widget.users
        .whereType<Map>()
        .where(
          (user) =>
              _branch.isEmpty ||
              (_branch == 'unassigned'
                  ? user['storeId'] == null
                  : user['storeId']?.toString() == _branch),
        )
        .toList(),
    searchFields: const ['name', 'phone', 'storeName'],
    onRefresh: widget.onRefresh,
    additionalFilters: [
      DropdownButtonFormField<String>(
        key: ValueKey('accounts-branch-$_branch'),
        initialValue: _branch,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Chi nhánh',
          prefixIcon: Icon(Icons.storefront_outlined),
        ),
        items: [
          const DropdownMenuItem(
            value: '',
            child: Text('Tất cả chi nhánh', overflow: TextOverflow.ellipsis),
          ),
          const DropdownMenuItem(
            value: 'unassigned',
            child: Text('Chưa phân chi nhánh', overflow: TextOverflow.ellipsis),
          ),
          ..._branches.entries.map(
            (entry) => DropdownMenuItem(
              value: entry.key,
              child: Text(entry.value, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: (value) => setState(() => _branch = value ?? ''),
      ),
    ],
    filterField: 'role',
    filterOptions: const {
      'STAFF': 'Nhân viên',
      'MANAGER': 'Quản lý',
      'ADMIN': 'Admin',
    },
    action: FilledButton.icon(
      onPressed: widget.onAddUser,
      icon: const Icon(Icons.person_add_outlined),
      label: const Text('Tạo tài khoản'),
    ),
    columns: const [
      'Họ tên',
      'Số điện thoại',
      'Chi nhánh',
      'Vai trò',
      'Trạng thái làm việc',
      'Thiết bị',
      '',
    ],
    cells: (u) => [
      DataCell(Text(u['name'] ?? '—')),
      DataCell(Text(u['phone'] ?? '—')),
      DataCell(Text(u['storeName'] ?? 'Chưa phân công')),
      DataCell(StatusBadge.fromStatus(u['role'])),
      DataCell(StatusBadge.fromStatus(u['employmentStatus'] ?? 'ACTIVE')),
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
                    StatusBadge.fromStatus(u['employmentStatus'] ?? 'ACTIVE'),
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
