import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class PageHeading extends StatelessWidget {
  final String title, subtitle;
  final Widget? action;
  const PageHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Wrap(
      spacing: 16,
      runSpacing: 12,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        if (action != null) action!,
      ],
    ),
  );
}

class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: padding, child: child),
  );
}

/// Wrap-based metrics grow vertically with text scaling instead of fixed aspect ratios.
class MetricGrid extends StatelessWidget {
  final List<Widget> children;
  const MetricGrid({super.key, required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns = box.maxWidth >= 850
          ? 4
          : box.maxWidth >= 340
          ? 2
          : 1;
      final width = (box.maxWidth - (columns - 1) * 12) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: children
            .map((child) => SizedBox(width: width, child: child))
            .toList(),
      );
    },
  );
}

class InlineNotice extends StatelessWidget {
  final String message;
  final bool error;
  const InlineNotice(this.message, {super.key, this.error = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: error ? AppColors.errorBg : AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          error ? Icons.error_outline : Icons.info_outline,
          size: 20,
          color: error ? AppColors.error : AppColors.textSecondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: TextStyle(
              color: error ? AppColors.error : AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    ),
  );
}
