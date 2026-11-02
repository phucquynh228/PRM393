import 'package:flutter/material.dart';

import 'package:hrm_app/core/theme/app_theme.dart';

class BranchHelpers {
  static String prettyDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  static String shortDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';

  static String formatIsoDate(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    return date == null ? '—' : prettyDate(date);
  }

  static String clockTime(dynamic value) {
    if (value == null) return '—';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  static String dateToYmd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Widget surfaceIcon(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );

  static Widget pill(String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.borderLight),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.primaryMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );

  static Widget infoBanner(String text) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.accentLight,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFFDE68A)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          color: AppColors.accent,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );

  static Widget dateBanner(DateTime date, {required VoidCallback onTap}) =>
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border, width: 1.2),
          boxShadow: AppColors.cardShadow,
        ),
        child: ListTile(
          onTap: onTap,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primarySubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          title: Text(
            prettyDate(date),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: const Text(
            'Chạm để chọn ngày',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          trailing: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.primary,
          ),
        ),
      );

  static Widget detailRow(IconData icon, String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(icon, color: AppColors.primaryMuted, size: 18),
        const SizedBox(width: 10),
        Text(
          '$title: ',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    ),
  );
}
