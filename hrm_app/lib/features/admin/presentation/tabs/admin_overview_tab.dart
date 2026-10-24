import 'package:flutter/material.dart';

import 'package:hrm_app/features/auth/data/models/login_response.dart';
import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/shared/presentation/models/dashboard_summary.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';
import 'package:hrm_app/shared/presentation/widgets/stat_metric_card.dart';
import 'package:hrm_app/shared/presentation/widgets/dashboard_widgets.dart';
import 'package:hrm_app/features/attendance/presentation/widgets/personal_attendance_card.dart';
import 'package:hrm_app/features/branch/presentation/helpers/branch_helpers.dart';

class AdminOverviewTab extends StatelessWidget {
  final LoginResponse loginResponse;
  final Map<String, dynamic>? dashboardData;
  final List<dynamic> stores, users, attendance;
  final Future<void> Function() onRefresh;
  final VoidCallback onAddStore, onAddUser;
  final ValueChanged<int> onNavigate;
  final void Function(Map<String, dynamic>) onEditStore;
  final bool dataReady;
  const AdminOverviewTab({
    super.key,
    required this.loginResponse,
    required this.dashboardData,
    required this.stores,
    required this.users,
    required this.attendance,
    required this.onRefresh,
    required this.onAddStore,
    required this.onAddUser,
    required this.onNavigate,
    required this.onEditStore,
    this.dataReady = true,
  });
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = attendanceOnDate(attendance, now);
    final working = today.where((a) => a['checkOutTime'] == null).length;
    final completed = today.where((a) => a['checkOutTime'] != null).length;
    final unassigned = stores
        .whereType<Map>()
        .where((s) => s['managerId'] == null)
        .toList();
    final noStore = users
        .whereType<Map>()
        .where((u) => u['role'] == 'STAFF' && u['storeId'] == null)
        .length;
    String count(Object? value) => dataReady ? '${value ?? 0}' : '—';
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < 950;
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              DashboardBanner(
                eyebrow: 'ĐIỀU HÀNH CHUỖI · ${BranchHelpers.prettyDate(now)}',
                title: 'Xin chào, ${loginResponse.name}',
                subtitle: 'Nắm tình hình đội ngũ, theo dõi chấm công và xử lý công việc trong ngày.',
                actions: [
                  DashboardAction(
                    label: 'Thêm chi nhánh',
                    icon: Icons.add_business_outlined,
                    onTap: onAddStore,
                  ),
                  DashboardAction(
                    label: 'Tạo tài khoản',
                    icon: Icons.person_add_outlined,
                    onTap: onAddUser,
                  ),
                  DashboardAction(
                    label: 'Xem chấm công',
                    icon: Icons.fact_check_outlined,
                    onTap: () => onNavigate(3),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (compact) ...[
                PersonalAttendanceCard(
                  name: loginResponse.name,
                  onChanged: () => onRefresh(),
                ),
                const SizedBox(height: 20),
              ],
              MetricGrid(
                children: [
                  StatMetricCard(
                    title: 'Chi nhánh',
                    value: count(
                      dashboardData?['totalStores'] ?? stores.length,
                    ),
                    subtitle:
                        '${stores.whereType<Map>().where((s) => s['status'] == 'ACTIVE').length} đang hoạt động',
                    icon: Icons.local_cafe_outlined,
                    color: AppColors.primary,
                    onTap: () => onNavigate(1),
                  ),
                  StatMetricCard(
                    title: 'Tài khoản',
                    value: count(dashboardData?['totalUsers'] ?? users.length),
                    subtitle: 'Nhân viên và quản lý',
                    icon: Icons.groups_outlined,
                    color: AppColors.accent,
                    onTap: () => onNavigate(2),
                  ),
                  StatMetricCard(
                    title: 'Vào ca hôm nay',
                    value: count(today.length),
                    subtitle: 'Tổng lượt đã check-in',
                    icon: Icons.fingerprint,
                    color: AppColors.primaryLight,
                    onTap: () => onNavigate(3),
                  ),
                  StatMetricCard(
                    title: 'Đang trong ca',
                    value: count(working),
                    subtitle: 'Đã vào ca, chưa ra ca',
                    icon: Icons.schedule_rounded,
                    color: AppColors.primaryDark,
                    onTap: () => onNavigate(3),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              DashboardColumns(
                side: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!compact) ...[
                      PersonalAttendanceCard(
                        name: loginResponse.name,
                        onChanged: () => onRefresh(),
                      ),
                      const SizedBox(height: 20),
                    ],
                    DashboardSection(
                      title: 'Việc cần chú ý',
                      subtitle: 'Truy cập nhanh các phần cần bổ sung thông tin',
                      child: !dataReady
                          ? const Text('Chưa tải được dữ liệu tổng quan.')
                          : Column(
                              children: [
                                if (unassigned.isNotEmpty)
                                  DashboardTask(
                                    title:
                                        '${unassigned.length} chi nhánh chưa có quản lý',
                                    detail: 'Bổ nhiệm quản lý để vận hành chi nhánh',
                                    icon: Icons.manage_accounts_outlined,
                                    onTap: unassigned.length == 1
                                        ? () => onEditStore(
                                            Map<String, dynamic>.from(
                                              unassigned.first,
                                            ),
                                          )
                                        : () => onNavigate(1),
                                  ),
                                if (noStore > 0)
                                  DashboardTask(
                                    title:
                                        '$noStore nhân viên chưa có chi nhánh',
                                    detail: 'Kiểm tra lại thông tin phân công',
                                    icon: Icons.person_pin_circle_outlined,
                                    onTap: () => onNavigate(2),
                                  ),
                                if (unassigned.isEmpty && noStore == 0)
                                  const DashboardTask(
                                    title: 'Thông tin đội ngũ đã đầy đủ',
                                    detail: 'Các chi nhánh đã có quản lý và nhân viên đã được phân công',
                                    icon: Icons.check_circle_outline,
                                    color: AppColors.success,
                                    onTap: null,
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
                main: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DashboardSection(
                      title: 'Chấm công hôm nay',
                      subtitle:
                          'Toàn hệ thống · ${BranchHelpers.prettyDate(now)}',
                      onOpen: () => onNavigate(3),
                      child: dataReady
                          ? AttendanceSummary(
                              working: working,
                              completed: completed,
                            )
                          : const Text('Chưa có dữ liệu đã xác nhận.'),
                    ),
                    const SizedBox(height: 20),
                    AttendanceActivity(
                      records: today,
                      onOpen: () => onNavigate(3),
                    ),
                    const SizedBox(height: 20),
                    DashboardSection(
                      title: 'Chi nhánh & nhân sự',
                      subtitle: 'Quản lý và sức chứa đội ngũ theo địa điểm',
                      onOpen: () => onNavigate(1),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (dataReady && stores.isEmpty)
                            const Text(
                              'Chưa có chi nhánh. Thêm chi nhánh đầu tiên để bắt đầu.',
                            ),
                          for (final s in stores.whereType<Map>().take(4))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () =>
                                    onEditStore(Map<String, dynamic>.from(s)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      const CircleAvatar(
                                        backgroundColor:
                                            AppColors.primarySubtle,
                                        child: Icon(
                                          Icons.storefront_outlined,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              s['name']?.toString() ??
                                                  'Chi nhánh',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              s['managerName']?.toString() ??
                                                  'Chưa bổ nhiệm quản lý',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        '${s['currentStaffCount'] ?? 0}/${s['maxStaff'] ?? '—'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.chevron_right, size: 18),
                                    ],
                                  ),
                                ),
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
        );
      },
    );
  }
}
