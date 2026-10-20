import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../blocs/branch/branch_cubit.dart';
import '../../../models/dashboard_summary.dart';
import '../../../widgets/content_widgets.dart';
import '../../../widgets/dashboard_widgets.dart';
import '../../../widgets/personal_attendance_card.dart';
import '../../../widgets/stat_metric_card.dart';
import '../../../widgets/status_badge.dart';
import '../branch_helpers.dart';

class BranchOverviewTab extends StatelessWidget {
  final String name;
  final BranchState state;
  final Future<void> Function() onRefresh;
  final ValueChanged<int> onNavigate;
  final VoidCallback onAssignShift, onAddStaff;
  final Future<void> Function(Map<String, dynamic>) onPublish, onApprove;
  const BranchOverviewTab({
    super.key,
    required this.name,
    required this.state,
    required this.onRefresh,
    required this.onNavigate,
    required this.onAssignShift,
    required this.onAddStaff,
    required this.onPublish,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayKey = BranchHelpers.dateToYmd(now);
    final raw = state.resources['dashboardAttendance'];
    final attendance = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final rows = branchAttendanceRecords(attendance);
    final week = (state.resources['dashboardSchedules'] as List? ?? [])
        .whereType<Map>()
        .map((s) => Map<String, dynamic>.from(s))
        .toList();
    final today = week.where((s) => s['date'] == todayKey).toList()
      ..sort(
        (a, b) => (a['startTime'] ?? '').toString().compareTo(
          (b['startTime'] ?? '').toString(),
        ),
      );
    final drafts = week.where((s) => s['published'] != true).toList();
    final requests = (state.resources['requests'] as List? ?? [])
        .whereType<Map>()
        .where((r) => r['status'] == 'PENDING')
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
    final ready = raw is Map;
    final schedulesReady = state.resources.containsKey('dashboardSchedules');
    final requestsReady = state.resources.containsKey('requests');
    final total = (attendance['total'] as num?)?.toInt() ?? 0;
    final checkedIn = (attendance['checkedIn'] as num?)?.toInt() ?? 0;
    final completed = (attendance['checkedOut'] as num?)?.toInt() ?? 0;
    final absent = (attendance['absent'] as num?)?.toInt() ?? 0;
    final pending = rows
        .where((r) => r['checkInTime'] == null && r['status'] != 'ABSENT')
        .length;
    String count(int n) => ready ? '$n' : '—';
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < 950;
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              DashboardBanner(
                eyebrow:
                    'ĐIỀU HÀNH CHI NHÁNH · ${BranchHelpers.prettyDate(now)}',
                title:
                    state.branch['name']?.toString() ?? 'Tổng quan chi nhánh',
                subtitle:
                    'Xin chào $name. Chấm công, phân ca và xử lý yêu cầu ngay tại đây.',
                actions: [
                  DashboardAction(
                    label: 'Phân ca mới',
                    icon: Icons.add_task_rounded,
                    onTap: state.staff.isEmpty || state.shifts.isEmpty
                        ? null
                        : onAssignShift,
                  ),
                  DashboardAction(
                    label: 'Thêm nhân viên',
                    icon: Icons.person_add_outlined,
                    onTap: onAddStaff,
                  ),
                  DashboardAction(
                    label: requestsReady
                        ? 'Duyệt đơn (${requests.length})'
                        : 'Duyệt đơn',
                    icon: Icons.mark_email_read_outlined,
                    onTap: () => onNavigate(3),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (compact) ...[
                PersonalAttendanceCard(
                  name: name,
                  onChanged: () => onRefresh(),
                ),
                const SizedBox(height: 20),
              ],
              MetricGrid(
                children: [
                  StatMetricCard(
                    title: 'Ca hôm nay',
                    value: count(total),
                    subtitle: 'Ca đã được công bố',
                    icon: Icons.calendar_today_outlined,
                    color: AppColors.primary,
                    onTap: () => onNavigate(2),
                  ),
                  StatMetricCard(
                    title: 'Đang trong ca',
                    value: count((checkedIn - completed).clamp(0, checkedIn)),
                    subtitle: 'Đã vào ca, chưa ra ca',
                    icon: Icons.fingerprint,
                    color: AppColors.primaryLight,
                    onTap: () => onNavigate(2),
                  ),
                  StatMetricCard(
                    title: 'Chờ vào ca',
                    value: count(pending),
                    subtitle: 'Ca chưa có check-in, chưa vắng',
                    icon: Icons.schedule,
                    color: AppColors.accent,
                    onTap: () => onNavigate(2),
                  ),
                  StatMetricCard(
                    title: 'Đơn chờ duyệt',
                    value: state.resources.containsKey('requests')
                        ? '${requests.length}'
                        : '—',
                    subtitle: 'Nghỉ phép và đổi ca',
                    icon: Icons.mail_outline,
                    color: AppColors.accent,
                    onTap: () => onNavigate(3),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              DashboardColumns(
                side: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!compact) ...[
                      PersonalAttendanceCard(
                        name: name,
                        onChanged: () => onRefresh(),
                      ),
                      const SizedBox(height: 20),
                    ],
                    DashboardSection(
                      title: 'Công việc cần xử lý',
                      subtitle: 'Tập trung vào những việc đang chờ',
                      child: Column(
                        children: [
                          DashboardTask(
                            title: schedulesReady
                                ? '${drafts.length} ca nháp trong tuần hiện tại'
                                : 'Chưa tải được lịch tuần',
                            detail: 'Công bố để nhân viên xem lịch làm',
                            icon: Icons.edit_calendar_outlined,
                            onTap: () => onNavigate(1),
                          ),
                          DashboardTask(
                            title: requestsReady
                                ? '${requests.length} đơn đang chờ duyệt'
                                : 'Chưa tải được danh sách yêu cầu',
                            detail: 'Xem lý do và phản hồi cho nhân viên',
                            icon: Icons.mark_email_unread_outlined,
                            color: AppColors.accent,
                            onTap: () => onNavigate(3),
                          ),
                          DashboardTask(
                            title:
                                '${state.staff.length} nhân viên trong đội ngũ',
                            detail:
                                'Định biên: ${state.branch['maxStaff'] ?? '—'} người',
                            icon: Icons.groups_outlined,
                            color: AppColors.primary,
                            onTap: () => onNavigate(4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                main: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DashboardSection(
                      title: 'Chấm công hôm nay',
                      subtitle:
                          'Ca đã công bố · ${BranchHelpers.prettyDate(now)}',
                      onOpen: () => onNavigate(2),
                      child: ready
                          ? AttendanceSummary(
                              working: (checkedIn - completed).clamp(
                                0,
                                checkedIn,
                              ),
                              completed: completed,
                              pending: pending,
                              absent: absent,
                              showUnattended: true,
                            )
                          : const Text(
                              'Chưa tải được chấm công hôm nay. Vui lòng làm mới.',
                            ),
                    ),
                    const SizedBox(height: 20),
                    DashboardSection(
                      title: 'Lịch làm hôm nay',
                      subtitle: 'Nhân viên, khung giờ và trạng thái công bố',
                      onOpen: () => onNavigate(1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (today.isEmpty)
                            Text(
                              schedulesReady
                                  ? 'Hôm nay chưa có ca làm trong lịch.'
                                  : 'Chưa tải được lịch làm. Vui lòng làm mới.',
                            ),
                          for (final s in today.take(4))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    s['userName']?.toString() ?? 'Nhân viên',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    '${s['shiftName']} · ${s['startTime']} – ${s['endTime']}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      StatusBadge.fromStatus(
                                        s['published'] == true
                                            ? 'PUBLISHED'
                                            : 'DRAFT',
                                      ),
                                      if (s['published'] != true)
                                        _QuickAction(
                                          label: 'Công bố ca',
                                          icon: Icons.publish_outlined,
                                          action: () => onPublish(s),
                                        ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    DashboardSection(
                      title: 'Yêu cầu cần duyệt',
                      subtitle: 'Xử lý nhanh hoặc mở chi tiết để phản hồi',
                      onOpen: () => onNavigate(3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (requests.isEmpty)
                            Text(
                              requestsReady
                                  ? 'Không có đơn đang chờ duyệt.'
                                  : 'Chưa tải được yêu cầu. Vui lòng làm mới.',
                            ),
                          for (final r in requests.take(3))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    r['userName']?.toString() ?? 'Nhân viên',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${r['type'] == 'LEAVE' ? 'Nghỉ phép' : 'Đổi ca'} · ${BranchHelpers.formatIsoDate(r['startDate'])}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(r['reason']?.toString() ?? ''),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 8,
                                    children: [
                                      _QuickAction(
                                        label: 'Duyệt đơn',
                                        icon: Icons.check,
                                        action: () => onApprove(r),
                                      ),
                                      TextButton(
                                        onPressed: () => onNavigate(3),
                                        child: const Text('Xem chi tiết'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    AttendanceActivity(
                      records: rows,
                      onOpen: () => onNavigate(2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickAction extends StatefulWidget {
  final String label;
  final IconData icon;
  final Future<void> Function() action;
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.action,
  });
  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: _busy
        ? null
        : () async {
            setState(() => _busy = true);
            try {
              await widget.action();
            } finally {
              if (mounted) setState(() => _busy = false);
            }
          },
    icon: Icon(widget.icon, size: 18),
    label: Text(_busy ? 'Đang xử lý…' : widget.label),
  );
}
