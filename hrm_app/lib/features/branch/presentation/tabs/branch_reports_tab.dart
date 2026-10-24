import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';
import 'package:hrm_app/shared/presentation/widgets/stat_metric_card.dart';
import 'package:hrm_app/features/branch/presentation/helpers/branch_helpers.dart';

class BranchReportsTab extends StatelessWidget {
  final Map<String, dynamic> report;
  final int staffCount;
  final DateTime reportFrom, reportTo;
  final VoidCallback onSelectReportRange;
  const BranchReportsTab({
    super.key,
    required this.report,
    required this.staffCount,
    required this.reportFrom,
    required this.reportTo,
    required this.onSelectReportRange,
  });
  @override
  Widget build(BuildContext context) {
    final daily = (report['daily'] as List? ?? []).whereType<Map>().toList();
    final maxValue = daily.fold<num>(
      1,
      (max, d) => math.max(
        max,
        math.max((d['scheduled'] as num?) ?? 0, (d['attended'] as num?) ?? 0),
      ),
    );
    Widget bar(num value, Color color, String label) => Semantics(
      label: '$label: $value',
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (value / maxValue).clamp(0, 1).toDouble(),
                minHeight: 8,
                color: color,
                backgroundColor: AppColors.surfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 30, child: Text('$value', textAlign: TextAlign.end)),
        ],
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PageHeading(
          title: 'Báo cáo chi nhánh',
          subtitle: 'Theo dõi phân ca và số lượt chấm công',
          action: OutlinedButton.icon(
            onPressed: onSelectReportRange,
            icon: const Icon(Icons.date_range),
            label: Text(
              '${BranchHelpers.shortDate(reportFrom)} – ${BranchHelpers.shortDate(reportTo)}',
            ),
          ),
        ),
        MetricGrid(
          children: [
            StatMetricCard(
              title: 'Nhân viên',
              value: '${report['staffCount'] ?? staffCount}',
              icon: Icons.people_outline,
            ),
            StatMetricCard(
              title: 'Ca đã lên lịch',
              value: '${report['scheduled'] ?? '—'}',
              icon: Icons.event_available_outlined,
            ),
            StatMetricCard(
              title: 'Lượt chấm công',
              value: '${report['attended'] ?? '—'}',
              icon: Icons.login_rounded,
              color: AppColors.success,
            ),
            StatMetricCard(
              title: 'Tỷ lệ có chấm công',
              value: report['attendanceRate'] == null
                  ? '—'
                  : '${(report['attendanceRate'] as num).toStringAsFixed(1)}%',
              icon: Icons.insights_outlined,
              color: AppColors.info,
            ),
          ],
        ),
        const SizedBox(height: 24),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Phân ca và chấm công theo ngày',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              const Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  Text(
                    '━ Ca đã lên lịch',
                    style: TextStyle(color: AppColors.primary),
                  ),
                  Text(
                    '━ Lượt chấm công',
                    style: TextStyle(color: AppColors.success),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (daily.isEmpty)
                const Text('Chưa có dữ liệu trong khoảng thời gian này.')
              else
                ...daily.map(
                  (day) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          BranchHelpers.formatIsoDate(day['date']),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        bar(
                          (day['scheduled'] as num?) ?? 0,
                          AppColors.primary,
                          'Ca đã lên lịch',
                        ),
                        const SizedBox(height: 6),
                        bar(
                          (day['attended'] as num?) ?? 0,
                          AppColors.success,
                          'Lượt chấm công',
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const InlineNotice(
          'Tỷ lệ chấm công = số bản ghi chấm công / số ca đã công bố trong kỳ. Chỉ số này không đánh giá đi làm đúng giờ.',
        ),
      ],
    );
  }
}
