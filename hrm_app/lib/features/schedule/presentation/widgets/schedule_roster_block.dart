import 'package:flutter/material.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/schedule/presentation/widgets/fixed_roster_editor.dart';
import 'package:hrm_app/features/staff/presentation/helpers/staff_helpers.dart';
import 'package:hrm_app/shared/presentation/widgets/status_badge.dart';

String scheduleSlot(Map<String, dynamic> row) {
  if (rosterSlots.containsKey(row['slot'])) return row['slot'] as String;
  final hour = int.tryParse('${row['startTime'] ?? '0'}'.split(':').first) ?? 0;
  return hour < 12
      ? 'MORNING'
      : hour < 17
      ? 'AFTERNOON'
      : 'EVENING';
}

/// Shared shift staffing view for branch managers and chain administrators.
class ScheduleRosterBlock extends StatelessWidget {
  final Map<String, dynamic> plan;
  final List<Map<String, dynamic>> assignments;
  final String filter;
  final Widget? footer;
  final Widget? Function(Map<String, dynamic>)? action;

  const ScheduleRosterBlock({
    super.key,
    required this.plan,
    required this.assignments,
    this.filter = 'ALL',
    this.footer,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final available = assignments
        .where(
          (s) => !['ON_LEAVE', 'ABSENT', 'CANCELLED'].contains(s['status']),
        )
        .map((s) => s['userId'])
        .toSet()
        .length;
    final required = (plan['requiredStaff'] as num?)?.toInt() ?? 0;
    final shortage = required > available;
    final visible = assignments
        .where(
          (s) =>
              s['status'] != 'CANCELLED' &&
              (filter == 'ALL' ||
                  (filter == 'DRAFT'
                      ? s['published'] != true
                      : s['published'] == true)),
        )
        .toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shortage ? AppColors.errorBg : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: shortage ? AppColors.error : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            rosterSlots[plan['slot']]!,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            plan['shiftId'] == null
                ? 'Chưa chọn mẫu giờ'
                : '${plan['shiftName']} · ${shortTime(plan['startTime'])}–${shortTime(plan['endTime'])}',
          ),
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Text(
              required == 0
                  ? '$available nhân viên · Chưa đặt định mức'
                  : shortage
                  ? 'Thiếu ${required - available} người · $available/$required nhân viên'
                  : 'Đủ nhân sự · $available/$required nhân viên',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: shortage
                    ? AppColors.error
                    : required > 0
                    ? AppColors.success
                    : AppColors.textSecondary,
              ),
            ),
          ),
          if (plan['shiftId'] != null && plan['active'] != true) ...[
            const SizedBox(height: 8),
            const Text('Mẫu ca đã ngừng dùng. Chọn lại trong Định mức ca.'),
          ],
          const SizedBox(height: 12),
          if (visible.isEmpty)
            Text(
              assignments.isEmpty
                  ? 'Chưa có nhân sự trong ca.'
                  : 'Không có phân công phù hợp bộ lọc.',
            ),
          for (final item in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['userName'] ?? 'Nhân viên',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item['shiftName']} · ${shortTime(item['startTime'])}–${shortTime(item['endTime'])}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            StatusBadge.fromStatus(
                              item['published'] == true ? 'PUBLISHED' : 'DRAFT',
                            ),
                            if (item['status'] != null &&
                                item['status'] != 'PENDING')
                              StatusBadge.fromStatus(item['status']),
                            if (item['temporaryTransfer'] == true)
                              const Text('Hỗ trợ chi nhánh'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ?action?.call(item),
                ],
              ),
            ),
          ?footer,
        ],
      ),
    );
  }
}
