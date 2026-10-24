import 'package:flutter/material.dart';

import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';

class DashboardBanner extends StatelessWidget {
  final String eyebrow, title, subtitle;
  final List<Widget> actions;
  const DashboardBanner({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.actions = const [],
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.primaryDark, AppColors.primary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(
              Icons.local_cafe_outlined,
              color: AppColors.amberBadge,
              size: 18,
            ),
            Text(
              eyebrow,
              style: const TextStyle(
                color: AppColors.amberBadge,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFFF1E7DF), height: 1.6),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(spacing: 10, runSpacing: 10, children: actions),
        ],
      ],
    ),
  );
}

class DashboardColumns extends StatelessWidget {
  final Widget main, side;
  const DashboardColumns({super.key, required this.main, required this.side});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => box.maxWidth >= 950
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: main),
              const SizedBox(width: 20),
              Expanded(flex: 5, child: side),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [side, const SizedBox(height: 20), main],
          ),
  );
}

class DashboardSection extends StatelessWidget {
  final String title;
  final Widget child;
  final String? subtitle, linkLabel;
  final VoidCallback? onOpen;
  const DashboardSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.onOpen,
    this.linkLabel,
  });
  @override
  Widget build(BuildContext context) => SurfaceCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 5),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (onOpen != null)
              TextButton(
                onPressed: onOpen,
                child: Text(linkLabel ?? 'Xem tất cả'),
              ),
          ],
        ),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );
}

class DashboardAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const DashboardAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = AppColors.primary,
  });
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: color,
      side: BorderSide(color: color.withValues(alpha: .22)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      minimumSize: const Size(44, 44),
    ),
    icon: Icon(icon, size: 19),
    label: Text(label),
  );
}

class DashboardTask extends StatelessWidget {
  final String title, detail;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const DashboardTask({
    super.key,
    required this.title,
    required this.detail,
    required this.icon,
    required this.onTap,
    this.color = AppColors.warning,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: color.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(detail, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AttendanceSummary extends StatelessWidget {
  final int working, completed, pending, absent;
  final bool showUnattended;
  const AttendanceSummary({
    super.key,
    required this.working,
    required this.completed,
    this.pending = 0,
    this.absent = 0,
    this.showUnattended = false,
  });
  @override
  Widget build(BuildContext context) {
    final parts = [
      ('Đang làm', working, AppColors.success),
      ('Đã ra ca', completed, AppColors.info),
      if (showUnattended) ('Chờ vào ca', pending, AppColors.warning),
      if (showUnattended) ('Vắng mặt', absent, AppColors.error),
    ];
    final total = parts.fold<int>(0, (n, p) => n + p.$2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          total == 0
              ? 'Chưa có dữ liệu chấm công hôm nay'
              : '$total ${showUnattended ? 'ca đã công bố' : 'lượt vào ca hôm nay'}',
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 12,
            child: total == 0
                ? const ColoredBox(color: AppColors.surfaceVariant)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final p in parts)
                        if (p.$2 > 0)
                          Expanded(
                            flex: p.$2,
                            child: ColoredBox(color: p.$3),
                          ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, box) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final p in parts)
                SizedBox(
                  width: (box.maxWidth - 12) / 2,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Icon(Icons.circle, size: 9, color: p.$3),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.$1,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              '${p.$2}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: p.$3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class AttendanceActivity extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  final VoidCallback onOpen;
  const AttendanceActivity({
    super.key,
    required this.records,
    required this.onOpen,
  });
  String _time(dynamic value) {
    final d = DateTime.tryParse(value?.toString() ?? '');
    return d == null
        ? '—'
        : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final recent = [...records.where((r) => r['checkInTime'] != null)]
      ..sort(
        (a, b) => (b['checkOutTime'] ?? b['checkInTime']).toString().compareTo(
          (a['checkOutTime'] ?? a['checkInTime']).toString(),
        ),
      );
    return DashboardSection(
      title: 'Chấm công gần đây',
      subtitle: 'Những lượt vào ca / ra ca mới nhất hôm nay',
      onOpen: onOpen,
      child: recent.isEmpty
          ? const Text(
              'Chưa có lượt chấm công hôm nay.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          : Column(
              children: [
                for (final r in recent.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 19,
                          backgroundColor: r['checkOutTime'] == null
                              ? AppColors.successBg
                              : AppColors.infoBg,
                          child: Icon(
                            r['checkOutTime'] == null
                                ? Icons.login_rounded
                                : Icons.logout_rounded,
                            size: 18,
                            color: r['checkOutTime'] == null
                                ? AppColors.success
                                : AppColors.info,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r['userName']?.toString() ?? 'Nhân viên',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                r['shiftName']?.toString() ?? 'Ca làm',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _time(r['checkOutTime'] ?? r['checkInTime']),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              r['checkOutTime'] == null ? 'Vào ca' : 'Ra ca',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
