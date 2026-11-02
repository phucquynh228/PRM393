import 'package:flutter/material.dart';

import 'package:hrm_app/core/theme/app_theme.dart';

class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onButtonPressed;
  final Color? iconColor;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.buttonText,
    this.onButtonPressed,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = iconColor ?? AppColors.primary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: effectiveColor.withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Icon(icon, size: 38, color: effectiveColor),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
            if (buttonText != null && onButtonPressed != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onButtonPressed,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(buttonText!),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
