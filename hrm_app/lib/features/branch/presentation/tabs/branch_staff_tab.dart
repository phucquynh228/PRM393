import 'package:flutter/material.dart';

import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';
import 'package:hrm_app/shared/presentation/widgets/directory_list.dart';
import 'package:hrm_app/features/branch/presentation/dialogs/branch_staff_sheets.dart';

class BranchStaffTab extends StatelessWidget {
  final List<Map<String, dynamic>> staff;
  final Map<String, dynamic>? branch;
  final String staffQuery;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onViewShifts;
  final Future<void> Function(String method, String path, {Object? data})
  onSend;
  final Future<void> Function() onReload;
  final void Function(String, {bool isError}) showMessage;
  final String Function(dynamic) cleanError;
  const BranchStaffTab({
    super.key,
    required this.staff,
    required this.branch,
    required this.staffQuery,
    required this.onQueryChanged,
    required this.onViewShifts,
    required this.onSend,
    required this.onReload,
    required this.showMessage,
    required this.cleanError,
  });
  void _form(BuildContext context, [Map<String, dynamic>? user]) =>
      BranchStaffFormSheet.show(
        context,
        staff: user,
        onSend: onSend,
        onReload: onReload,
        showMessage: showMessage,
        cleanError: cleanError,
      );
  Widget _actions(BuildContext context, Map<String, dynamic> user) =>
      PopupMenuButton<String>(
        tooltip: 'Thông tin nhân viên',
        onSelected: (value) {
          if (value == 'edit') {
            _form(context, user);
          } else {
            BranchStaffDetailsSheet.show(
              context,
              staff: user,
              branchName: branch?['name'] ?? '—',
              onViewShifts: onViewShifts,
            );
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'details', child: Text('Xem thông tin')),
          PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
        ],
      );
  @override
  Widget build(BuildContext context) => DirectoryList(
    title: 'Đội ngũ chi nhánh',
    subtitle: '${staff.length} / ${branch?['maxStaff'] ?? '—'} nhân viên',
    items: staff,
    searchFields: const ['name', 'phone'],
    onRefresh: onReload,
    action: FilledButton.icon(
      onPressed: () => _form(context),
      icon: const Icon(Icons.person_add_outlined),
      label: const Text('Thêm nhân viên'),
    ),
    columns: const ['Họ tên', 'Số điện thoại', 'Thiết bị', 'Sửa', ''],
    cells: (s) => [
      DataCell(Text(s['name'] ?? '—')),
      DataCell(Text(s['phone'] ?? '—')),
      DataCell(Text(s['deviceId'] == null ? 'Chưa liên kết' : 'Đã liên kết')),
      DataCell(
        IconButton(
          tooltip: 'Sửa nhân viên',
          onPressed: () => _form(context, s),
          icon: const Icon(Icons.edit_outlined),
        ),
      ),
      DataCell(_actions(context, s)),
    ],
    itemBuilder: (s) => SurfaceCard(
      child: Row(
        children: [
          const CircleAvatar(child: Icon(Icons.person_outline)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s['name'] ?? '—',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(s['phone'] ?? '—'),
                const SizedBox(height: 6),
                Text(
                  s['deviceId'] == null
                      ? 'Chưa liên kết thiết bị'
                      : 'Đã liên kết thiết bị',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Sửa nhân viên',
            onPressed: () => _form(context, s),
            icon: const Icon(Icons.edit_outlined),
          ),
          _actions(context, s),
        ],
      ),
    ),
  );
}
