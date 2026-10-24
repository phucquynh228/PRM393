import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class ScheduleWeekStrip extends StatelessWidget {
  final DateTime from;
  final DateTime? selected;
  final Map<String, int> counts;
  final ValueChanged<DateTime> onSelected;
  const ScheduleWeekStrip({
    super.key,
    required this.from,
    this.selected,
    required this.counts,
    required this.onSelected,
  });

  static String keyOf(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: List.generate(7, (i) {
        final day = from.add(Duration(days: i));
        final active = selected != null && DateUtils.isSameDay(day, selected);
        final today = DateUtils.isSameDay(day, DateTime.now());
        final count = counts[keyOf(day)] ?? 0;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Semantics(
            selected: active,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: active ? AppColors.primary : AppColors.surface,
                foregroundColor: active ? Colors.white : AppColors.textPrimary,
                side: BorderSide(
                  color: today ? AppColors.primary : AppColors.border,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              onPressed: () => onSelected(day),
              child: Column(
                children: [
                  Text(i == 6 ? 'CN' : 'T${i + 2}'),
                  const SizedBox(height: 6),
                  Text(
                    '${day.day}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    count == 0 ? 'Trống' : '$count ca',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    ),
  );
}
