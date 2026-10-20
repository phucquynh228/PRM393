import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../widgets/content_widgets.dart';
import '../../../widgets/directory_list.dart';
import '../../../widgets/stat_metric_card.dart';
import '../../../widgets/status_badge.dart';
import '../branch_helpers.dart';

class BranchAttendanceTab extends StatelessWidget {
  final List<Map<String, dynamic>> attendance;
  final int total, checkedIn, checkedOut, absent;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;
  final Future<void> Function() onRefresh;
  final Future<void> Function({
    required DateTime initial,
    DateTime? firstDate,
    DateTime? lastDate,
    required ValueChanged<DateTime> onPicked,
  })
  onPickDate;
  const BranchAttendanceTab({
    super.key,
    required this.attendance,
    required this.total,
    required this.checkedIn,
    required this.checkedOut,
    required this.absent,
    required this.selectedDate,
    required this.onDateChanged,
    required this.onPickDate,
    required this.onRefresh,
  });
  @override
  Widget build(BuildContext context) => DirectoryList(
    title: 'Chấm công chi nhánh',
    subtitle: 'Tình trạng vào ca và ra ca theo ngày',
    items: attendance,
    searchFields: const ['userName', 'shiftName'],
    onRefresh: onRefresh,
    filterField: 'status',
    filterOptions: const {
      'NOT_CHECKED_IN': 'Chờ vào ca',
      'CHECKED_IN': 'Đang làm',
      'CHECKED_OUT': 'Hoàn thành',
      'ABSENT': 'Vắng mặt',
    },
    action: OutlinedButton.icon(
      onPressed: () =>
          onPickDate(initial: selectedDate, onPicked: onDateChanged),
      icon: const Icon(Icons.calendar_today_outlined),
      label: Text(BranchHelpers.prettyDate(selectedDate)),
    ),
    leading: Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: MetricGrid(
        children: [
          StatMetricCard(
            title: 'Ca đã công bố',
            value: '$total',
            icon: Icons.event_available_outlined,
          ),
          StatMetricCard(
            title: 'Có giờ vào ca',
            value: '$checkedIn',
            icon: Icons.login_rounded,
            color: AppColors.success,
          ),
          StatMetricCard(
            title: 'Đã ra ca',
            value: '$checkedOut',
            icon: Icons.task_alt,
            color: AppColors.info,
          ),
          StatMetricCard(
            title: 'Vắng mặt',
            value: '$absent',
            icon: Icons.person_off_outlined,
            color: AppColors.warning,
          ),
        ],
      ),
    ),
    columns: const ['Nhân viên', 'Ca làm', 'Vào ca', 'Ra ca', 'Trạng thái'],
    cells: (a) => [
      DataCell(Text(a['userName'] ?? '—')),
      DataCell(Text(a['shiftName'] ?? '—')),
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
          Text(a['shiftName'] ?? '—'),
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
