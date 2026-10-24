import 'package:flutter/material.dart';

import 'package:hrm_app/core/theme/app_theme.dart';

enum BadgeVariant { success, warning, error, info, neutral }

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeVariant variant;
  final IconData? icon;
  final bool isSmall;
  const StatusBadge({
    super.key,
    required this.label,
    required this.variant,
    this.icon,
    this.isSmall = false,
  });
  factory StatusBadge.fromStatus(String? status, {bool isSmall = false}) {
    final (label, variant, icon) = switch ((status ?? '').toUpperCase()) {
      'ACTIVE' ||
      'OPEN' => ('Hoạt động', BadgeVariant.success, Icons.circle_outlined),
      'APPROVED' => (
        'Đã duyệt',
        BadgeVariant.success,
        Icons.check_circle_outline,
      ),
      'CHECKED_IN' ||
      'PRESENT' => ('Đang làm', BadgeVariant.success, Icons.login_rounded),
      'CHECKED_OUT' ||
      'COMPLETED' => ('Hoàn thành', BadgeVariant.info, Icons.task_alt),
      'NOT_CHECKED_IN' => ('Chờ vào ca', BadgeVariant.warning, Icons.schedule),
      'PENDING' ||
      'WAITING' => ('Chờ xử lý', BadgeVariant.warning, Icons.schedule),
      'PUBLISHED' => (
        'Đã công bố',
        BadgeVariant.success,
        Icons.check_circle_outline,
      ),
      'DRAFT' => ('Bản nháp', BadgeVariant.neutral, Icons.edit_outlined),
      'MAINTENANCE' => ('Bảo trì', BadgeVariant.warning, Icons.build_outlined),
      'REJECTED' => ('Từ chối', BadgeVariant.error, Icons.cancel_outlined),
      'CANCELLED' => ('Đã hủy', BadgeVariant.neutral, Icons.cancel_outlined),
      'ON_LEAVE' => (
        'Nghỉ phép',
        BadgeVariant.info,
        Icons.beach_access_outlined,
      ),
      'ABSENT' => ('Vắng mặt', BadgeVariant.error, Icons.person_off_outlined),
      'CLOSED' || 'INACTIVE' => (
        'Ngừng hoạt động',
        BadgeVariant.neutral,
        Icons.pause_circle_outline,
      ),
      'ADMIN' ||
      'ROLE_ADMIN' => ('Admin', BadgeVariant.info, Icons.shield_outlined),
      'MANAGER' ||
      'ROLE_MANAGER' => ('Quản lý', BadgeVariant.neutral, Icons.store_outlined),
      'STAFF' ||
      'ROLE_STAFF' => ('Nhân viên', BadgeVariant.neutral, Icons.badge_outlined),
      _ => ('Chưa xác định', BadgeVariant.neutral, Icons.help_outline),
    };
    return StatusBadge(
      label: label,
      variant: variant,
      icon: icon,
      isSmall: isSmall,
    );
  }
  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (variant) {
      BadgeVariant.success => (AppColors.success, AppColors.successBg),
      BadgeVariant.warning => (AppColors.warning, AppColors.warningBg),
      BadgeVariant.error => (AppColors.error, AppColors.errorBg),
      BadgeVariant.info => (AppColors.info, AppColors.infoBg),
      BadgeVariant.neutral => (
        AppColors.textSecondary,
        AppColors.surfaceVariant,
      ),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
