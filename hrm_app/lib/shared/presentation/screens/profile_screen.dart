import 'package:flutter/material.dart';

import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';
import 'package:hrm_app/shared/presentation/widgets/status_badge.dart';

class ProfileScreen extends StatelessWidget {
  final String name;
  final String role;
  final Map<String, Object?> details;
  final bool loading;
  final String? error;
  final VoidCallback? onRefresh;
  final String title;
  final Widget? footer;

  const ProfileScreen({
    super.key,
    required this.name,
    required this.role,
    required this.details,
    this.loading = false,
    this.error,
    this.onRefresh,
    this.title = 'Hồ sơ cá nhân',
    this.footer,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      actions: [
        if (onRefresh != null)
          IconButton(
            tooltip: 'Làm mới hồ sơ',
            onPressed: loading ? null : onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
      ],
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (loading) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
              ],
              if (error != null) ...[
                InlineNotice(error!, error: true),
                const SizedBox(height: 16),
              ],
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 32,
                      child: Icon(Icons.person_outline, size: 32),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    StatusBadge.fromStatus(role),
                    const SizedBox(height: 24),
                    for (final entry in details.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              entry.value == null ||
                                      entry.value.toString().trim().isEmpty
                                  ? 'Chưa cập nhật'
                                  : entry.value.toString(),
                            ),
                          ],
                        ),
                      ),
                    if (footer != null) footer!,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
