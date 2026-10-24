import 'package:flutter/material.dart';

import 'package:hrm_app/core/theme/app_theme.dart';

class CustomTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController controller;
  final List<Widget> tabs;
  final bool isScrollable;

  const CustomTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    this.isScrollable = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(66);

  @override
  Widget build(BuildContext context) {
    // Automatically optimize Tab widgets with icon and text to prevent vertical overflow
    final processedTabs = tabs.map((tab) {
      if (tab is Tab && tab.icon != null && tab.text != null) {
        return Tab(
          key: tab.key,
          text: tab.text,
          icon: tab.icon,
          iconMargin: const EdgeInsets.only(bottom: 3),
          height: tab.height,
          child: tab.child,
        );
      }
      return tab;
    }).toList();

    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        color: AppColors.primaryDark,
        border: Border(bottom: BorderSide(color: Color(0xFF382218), width: 1)),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: isScrollable,
        tabAlignment: isScrollable ? TabAlignment.start : TabAlignment.fill,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(12),
        indicator: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.amberBadge.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        labelColor: AppColors.amberBadge,
        unselectedLabelColor: Colors.white.withValues(alpha: 0.75),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        tabs: processedTabs,
      ),
    );
  }
}
