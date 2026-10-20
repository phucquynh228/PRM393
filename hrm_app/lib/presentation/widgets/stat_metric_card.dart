import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class StatMetricCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final Color? color;
  final String? subtitle;
  final VoidCallback? onTap;
  const StatMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.color,
    this.subtitle,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary;
    return Material(
      color: Color.alphaBlend(accent.withValues(alpha: .055), Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: accent.withValues(alpha: .18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 4, color: accent),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: .11),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: accent, size: 22),
                      ),
                      if (onTap != null) ...[
                        const Spacer(),
                        Icon(Icons.north_east, size: 17, color: accent),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
