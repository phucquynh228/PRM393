import 'package:flutter/material.dart';

import '../../../widgets/content_widgets.dart';
import '../../../widgets/directory_list.dart';
import '../../../widgets/status_badge.dart';

class AdminBranchesTab extends StatelessWidget {
  final List<dynamic> stores;
  final Future<void> Function() onRefresh;
  final VoidCallback onAddStore;
  final void Function(Map<String, dynamic>) onEditStore;
  final void Function(int, String) onDeleteStore;
  const AdminBranchesTab({
    super.key,
    required this.stores,
    required this.onRefresh,
    required this.onAddStore,
    required this.onEditStore,
    required this.onDeleteStore,
  });
  Widget _actions(Map<String, dynamic> store) => PopupMenuButton<String>(
    tooltip: 'Thao tác chi nhánh',
    onSelected: (value) => value == 'edit'
        ? onEditStore(store)
        : onDeleteStore(store['id'], store['name'] ?? ''),
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
      PopupMenuItem(value: 'delete', child: Text('Xóa chi nhánh')),
    ],
  );
  @override
  Widget build(BuildContext context) => DirectoryList(
    title: 'Chi nhánh',
    subtitle: 'Địa điểm, quản lý và định biên nhân sự',
    items: stores,
    searchFields: const ['name', 'code', 'managerName'],
    onRefresh: onRefresh,
    filterField: 'status',
    filterOptions: const {
      'ACTIVE': 'Hoạt động',
      'MAINTENANCE': 'Bảo trì',
      'CLOSED': 'Ngừng hoạt động',
    },
    action: FilledButton.icon(
      onPressed: onAddStore,
      icon: const Icon(Icons.add_business_outlined),
      label: const Text('Thêm chi nhánh'),
    ),
    columns: const [
      'Mã',
      'Chi nhánh',
      'Quản lý',
      'Nhân sự',
      'Trạng thái',
      'Sửa',
      '',
    ],
    cells: (s) => [
      DataCell(Text(s['code'] ?? '—')),
      DataCell(Text(s['name'] ?? '—')),
      DataCell(Text(s['managerName'] ?? 'Chưa bổ nhiệm')),
      DataCell(Text('${s['currentStaffCount'] ?? 0}/${s['maxStaff'] ?? '—'}')),
      DataCell(StatusBadge.fromStatus(s['status'])),
      DataCell(
        IconButton(
          tooltip: 'Chỉnh sửa chi nhánh',
          onPressed: () => onEditStore(s),
          icon: const Icon(Icons.edit_outlined),
        ),
      ),
      DataCell(_actions(s)),
    ],
    itemBuilder: (s) => SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s['code'] ?? 'CHI NHÁNH',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s['name'] ?? '—',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Chỉnh sửa chi nhánh',
                onPressed: () => onEditStore(s),
                icon: const Icon(Icons.edit_outlined),
              ),
              _actions(s),
            ],
          ),
          const SizedBox(height: 12),
          StatusBadge.fromStatus(s['status']),
          const SizedBox(height: 14),
          Text('Quản lý: ${s['managerName'] ?? 'Chưa bổ nhiệm'}'),
          const SizedBox(height: 6),
          Text(
            'Nhân sự: ${s['currentStaffCount'] ?? 0} / ${s['maxStaff'] ?? '—'} người',
          ),
        ],
      ),
    ),
  );
}
