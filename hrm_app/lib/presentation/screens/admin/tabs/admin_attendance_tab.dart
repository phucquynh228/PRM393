import 'package:flutter/material.dart';

import '../../../widgets/content_widgets.dart';
import '../../../widgets/directory_list.dart';
import '../../../widgets/status_badge.dart';
import '../../branch/branch_helpers.dart';

class AdminAttendanceTab extends StatelessWidget {
  final List<dynamic> attendanceList;
  final Future<void> Function() onRefresh;
  const AdminAttendanceTab({
    super.key,
    required this.attendanceList,
    required this.onRefresh,
  });
  @override
  Widget build(BuildContext context) => DirectoryList(
    title: 'Chấm công toàn hệ thống',
    initialDate: DateTime.now(),
    subtitle: 'Tra cứu lịch sử theo nhân viên, ngày và trạng thái',
    items: attendanceList,
    searchFields: const ['userName', 'shiftName'],
    onRefresh: onRefresh,
    filterField: 'status',
    filterOptions: const {
      'CHECKED_IN': 'Đang làm',
      'CHECKED_OUT': 'Hoàn thành',
      'ABSENT': 'Vắng mặt',
    },
    dateField: 'checkInTime',
    columns: const [
      'Nhân viên',
      'Ca làm',
      'Ngày',
      'Vào ca',
      'Ra ca',
      'Trạng thái',
    ],
    cells: (a) => [
      DataCell(Text(a['userName'] ?? '—')),
      DataCell(Text(a['shiftName'] ?? '—')),
      DataCell(Text(BranchHelpers.formatIsoDate(a['checkInTime']))),
      DataCell(Text(BranchHelpers.clockTime(a['checkInTime']))),
      DataCell(Text(BranchHelpers.clockTime(a['checkOutTime']))),
      DataCell(StatusBadge.fromStatus(a['status'])),
    ],
    itemBuilder: (a) => SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                a['userName'] ?? '—',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              StatusBadge.fromStatus(a['status']),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${a['shiftName'] ?? '—'} · ${BranchHelpers.formatIsoDate(a['checkInTime'])}',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              Text('Vào: ${BranchHelpers.clockTime(a['checkInTime'])}'),
              Text('Ra: ${BranchHelpers.clockTime(a['checkOutTime'])}'),
            ],
          ),
        ],
      ),
    ),
  );
}
