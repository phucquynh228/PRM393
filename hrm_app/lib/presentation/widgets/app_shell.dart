import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class AppDestination {
  final String label;
  final IconData icon;
  final int count;
  const AppDestination(this.label, this.icon, {this.count = 0});
  Widget get iconWidget => count > 0
      ? Badge(label: Text(count > 99 ? '99+' : '$count'), child: Icon(icon))
      : Icon(icon);
}

/// Bottom navigation on phones, rail/sidebar when there is room.
class AppShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final int selectedIndex;
  final List<AppDestination> destinations;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;
  final VoidCallback? onRefresh;
  final VoidCallback onLogout;
  final bool refreshing;
  final String? error;
  const AppShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.selectedIndex,
    required this.destinations,
    required this.onDestinationSelected,
    required this.child,
    required this.onLogout,
    this.onRefresh,
    this.refreshing = false,
    this.error,
  });

  void _showMore(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Công cụ chi nhánh',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (int i = 4; i < destinations.length; i++)
              ListTile(
                selected: selectedIndex == i,
                leading: destinations[i].iconWidget,
                title: Text(destinations[i].label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onDestinationSelected(i);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 760;
      final overflow = destinations.length > 5;
      final mobileDestinations = overflow
          ? [
              ...destinations.take(4),
              const AppDestination('Thêm', Icons.grid_view_rounded),
            ]
          : destinations;
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primarySubtle,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.local_cafe_outlined,
                  size: 21,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          toolbarHeight: 76,
          actions: [
            if (onRefresh != null)
              IconButton(
                tooltip: 'Làm mới dữ liệu',
                onPressed: refreshing ? null : onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            IconButton(
              tooltip: 'Đăng xuất',
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded),
            ),
            const SizedBox(width: 8),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: NavigationBar(
                  selectedIndex: overflow && selectedIndex >= 4
                      ? 4
                      : selectedIndex,
                  onDestinationSelected: (index) {
                    if (overflow && index == 4) {
                      _showMore(context);
                    } else {
                      onDestinationSelected(index);
                    }
                  },
                  destinations: mobileDestinations
                      .map(
                        (d) => NavigationDestination(
                          icon: d.iconWidget,
                          label: d.label,
                        ),
                      )
                      .toList(),
                ),
              ),
        body: SafeArea(
          top: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide) ...[
                NavigationRail(
                  scrollable: true,
                  extended: constraints.maxWidth >= 1150,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  labelType: constraints.maxWidth >= 1150
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.local_cafe_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        if (constraints.maxWidth >= 1150) ...[
                          const SizedBox(width: 12),
                          Text(
                            'HRM Cafe',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                  destinations: destinations
                      .map(
                        (d) => NavigationRailDestination(
                          icon: d.iconWidget,
                          label: Text(d.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: Column(
                  children: [
                    if (refreshing) const LinearProgressIndicator(minHeight: 2),
                    if (error != null)
                      Material(
                        color: AppColors.errorBg,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: AppColors.error,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  error!,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                              if (onRefresh != null)
                                TextButton(
                                  onPressed: refreshing ? null : onRefresh,
                                  child: const Text('Thử lại'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1360),
                          child: SizedBox(width: double.infinity, child: child),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
