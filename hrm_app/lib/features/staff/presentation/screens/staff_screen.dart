import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/staff/data/repositories/staff_repository.dart';
import 'package:hrm_app/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:hrm_app/features/staff/presentation/cubit/staff_cubit.dart';
import 'package:hrm_app/shared/presentation/widgets/app_shell.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';
import 'package:hrm_app/shared/presentation/widgets/empty_state_view.dart';
import 'package:hrm_app/shared/presentation/widgets/stat_metric_card.dart';
import 'package:hrm_app/shared/presentation/widgets/status_badge.dart';
import 'package:hrm_app/features/branch/presentation/helpers/branch_helpers.dart';
import 'package:hrm_app/features/auth/presentation/screens/login_screen.dart';
import 'package:hrm_app/features/staff/presentation/helpers/staff_helpers.dart';
import 'package:hrm_app/features/staff/presentation/dialogs/staff_profile_form.dart';
import 'package:hrm_app/features/staff/presentation/dialogs/staff_request_form.dart';
import 'package:hrm_app/features/staff/presentation/tabs/staff_requests_tab.dart';
import 'package:hrm_app/features/staff/presentation/tabs/staff_schedule_tab.dart';
import 'package:hrm_app/features/staff/presentation/widgets/staff_shift_card.dart';

class StaffScreen extends StatelessWidget {
  final String? name;
  const StaffScreen({super.key, this.name});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => StaffCubit(
      StaffRepository(context.read<Dio>()),
      context.read<AttendanceRepository>(),
    )..load(),
    child: _StaffWorkspace(name: name),
  );
}

class _StaffWorkspace extends StatefulWidget {
  final String? name;
  const _StaffWorkspace({this.name});
  @override
  State<_StaffWorkspace> createState() => _StaffWorkspaceState();
}

class _StaffWorkspaceState extends State<_StaffWorkspace>
    with WidgetsBindingObserver {
  int _index = 0;
  String _attendanceFilter = 'ALL';
  bool _unreadOnly = false;
  DateTimeRange? _historyRange;
  Timer? _timer;
  StaffCubit get cubit => context.read<StaffCubit>();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
          !cubit.state.busy &&
          !cubit.state.loading) {
        cubit.load();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !cubit.state.loading) {
      cubit.load();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _select(int index) => setState(() => _index = index);

  Future<void> _create({String type = 'LEAVE', int? scheduleId}) async {
    if (cubit.state.busy || cubit.state.loading) return;
    final created = await StaffRequestForm.show(
      context,
      cubit.repository,
      type: type,
      scheduleId: scheduleId,
    );
    if (!mounted || created != true) return;
    _select(3);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã gửi yêu cầu tới quản lý.')),
    );
    await cubit.load();
  }

  Future<void> _editProfile({bool password = false}) async {
    final saved = await StaffProfileForm.show(
      context,
      cubit.repository,
      cubit.state.profile,
      password: password,
    );
    if (!mounted || saved != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(password ? 'Đã đổi mật khẩu.' : 'Đã cập nhật hồ sơ.'),
      ),
    );
    await cubit.load();
  }

  Future<void> _logout() async {
    if (!await staffConfirm(
      context,
      'Đăng xuất?',
      'Bạn muốn kết thúc phiên làm việc này?',
    )) {
      return;
    }
    try {
      await const FlutterSecureStorage().delete(key: 'jwt_token');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa thể đăng xuất. Vui lòng thử lại.'),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _details(StaffItem shift) {
    final record = cubit.state
        .items('attendance')
        .where((a) => a['scheduleId'] == shift['id'])
        .firstOrNull;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${shift['shiftName']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mã ca: #${shift['id']}'),
              const SizedBox(height: 12),
              Text('Chi nhánh: ${shift['storeName'] ?? '—'}'),
              Text('Bắt đầu: ${stamp(shift['startsAt'])}'),
              Text('Kết thúc: ${stamp(shift['endsAt'])}'),
              const SizedBox(height: 12),
              StatusBadge.fromStatus('${shift['status']}'),
              if (record != null) ...[
                const SizedBox(height: 12),
                Text('Vào ca: ${stamp(record['checkInTime'])}'),
                Text('Ra ca: ${stamp(record['checkOutTime'])}'),
                Text(
                  'Giờ thực tế: ${record['checkOutTime'] == null ? 'Đang tính, chưa ra ca' : minutesLabel(record['workedMinutes'])}',
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<StaffCubit, StaffState>(
    listener: (context, state) {
      if (state.message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(state.message!)));
      }
    },
    builder: (context, state) => AppShell(
      title: 'HRM Cafe',
      subtitle:
          state.profile['storeName']?.toString() ?? 'Không gian nhân viên',
      selectedIndex: _index,
      destinations: [
        const AppDestination('Trang chủ', Icons.home_outlined),
        const AppDestination('Chấm công', Icons.fingerprint),
        const AppDestination('Lịch làm', Icons.calendar_month_outlined),
        AppDestination('Yêu cầu', Icons.mail_outline, count: state.pending),
        AppDestination(
          'Thông báo',
          Icons.notifications_outlined,
          count: state.unread,
        ),
        const AppDestination('Hồ sơ', Icons.person_outline),
      ],
      onDestinationSelected: _select,
      onLogout: _logout,
      onRefresh: state.busy ? null : () => cubit.load(),
      refreshing: state.loading || state.busy,
      error: state.error,
      child: !state.initialized
          ? (state.loading
                ? const Center(child: CircularProgressIndicator())
                : EmptyStateView(
                    icon: Icons.cloud_off_outlined,
                    title: 'Chưa tải được dữ liệu Staff',
                    message: 'Kiểm tra kết nối và bấm thử lại.',
                    buttonText: 'Thử lại',
                    onButtonPressed: () => cubit.load(),
                  ))
          : IndexedStack(
              index: _index,
              children: [
                _dashboard(state),
                _attendance(state),
                StaffScheduleTab(
                  request: () => _create(),
                  state: state,
                  refresh: () => cubit.load(),
                  change: ({anchor, month}) =>
                      cubit.load(anchor: anchor, month: month),
                  details: _details,
                  swap: (s) =>
                      _create(type: 'SHIFT_SWAP', scheduleId: s['id'] as int),
                ),
                StaffRequestsTab(
                  items: state.items('requests'),
                  busy: state.busy || state.loading,
                  refresh: () => cubit.load(),
                  create: () => _create(),
                  cancel: cubit.cancel,
                ),
                _notifications(state),
                _profile(state),
              ],
            ),
    ),
  );

  Widget _list(List<Widget> children) => RefreshIndicator(
    onRefresh: () => cubit.load(),
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: children,
    ),
  );

  Widget _section(String title, {VoidCallback? more}) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (more != null)
          TextButton(onPressed: more, child: const Text('Xem tất cả')),
      ],
    ),
  );

  StaffItem? _record(StaffState state, StaffItem shift) => state
      .items('attendance')
      .where((a) => a['scheduleId'] == shift['id'])
      .firstOrNull;

  Widget _shift(StaffState state, StaffItem shift) {
    final record = _record(state, shift);
    final start = DateTime.tryParse('${shift['startsAt']}');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: StaffShiftCard(
        schedule: shift,
        record: record,
        attendanceActions: true,
        busy: state.busy || state.loading,
        onCheckIn: () => cubit.checkIn(shift['id'] as int),
        onCheckOut: record == null || record['checkOutTime'] != null
            ? null
            : () => cubit.checkOut(record['id'] as int),
        onDetails: () => _details(shift),
        onSwap:
            shift['status'] == 'PENDING' &&
                (start?.isAfter(DateTime.now()) ?? false)
            ? () => _create(type: 'SHIFT_SWAP', scheduleId: shift['id'] as int)
            : null,
      ),
    );
  }

  Widget _dashboard(StaffState state) {
    final profile = state.profile, shifts = state.items('today');
    return _list([
      SurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.local_cafe_outlined,
              size: 32,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Xin chào, ${profile['name'] ?? widget.name ?? 'bạn'}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '${BranchHelpers.prettyDate(DateTime.now())} · ${profile['storeName'] ?? 'Chưa gán chi nhánh'}',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: state.busy || state.loading
                      ? null
                      : () => _create(),
                  icon: const Icon(Icons.add),
                  label: const Text('Gửi yêu cầu'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _select(2),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Lịch của tôi'),
                ),
                Badge(
                  isLabelVisible: state.unread > 0,
                  label: Text('${state.unread}'),
                  child: IconButton(
                    tooltip: 'Thông báo của tôi',
                    onPressed: () => _select(4),
                    icon: const Icon(Icons.notifications_outlined),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _section('Ca làm hôm nay', more: () => _select(2)),
      if (shifts.isEmpty)
        const EmptyStateView(
          icon: Icons.free_breakfast_outlined,
          title: 'Hôm nay chưa có ca làm',
          message: 'Lịch sẽ xuất hiện sau khi quản lý công bố.',
        ),
      ...shifts.map((s) => _shift(state, s)),
      const InlineNotice(
        'Check-in cần vị trí hiện tại để kiểm tra phạm vi chi nhánh. Bạn có thể gửi đơn sửa công nếu quên chấm công.',
      ),
      _section('Tổng quan tuần này'),
      MetricGrid(
        children: [
          StatMetricCard(
            title: 'Giờ công tuần này',
            value: compactHours(state.data['weekWorkedMinutes']),
            icon: Icons.schedule,
            subtitle: 'Chỉ cộng thời gian đã check-out',
            onTap: () => _select(1),
          ),
          StatMetricCard(
            title: 'Giờ được phân công',
            value: compactHours(state.data['weekPlannedMinutes']),
            icon: Icons.calendar_month_outlined,
            subtitle: 'Tuần hiện tại · không gồm ca nghỉ',
            onTap: () => _select(2),
          ),
          StatMetricCard(
            title: 'Yêu cầu chờ duyệt',
            value: '${state.pending}',
            icon: Icons.mail_outline,
            onTap: () => _select(3),
          ),
          StatMetricCard(
            title: 'Thông báo chưa đọc',
            value: '${state.unread}',
            icon: Icons.notifications_outlined,
            onTap: () => _select(4),
          ),
        ],
      ),
      _section('Thông báo gần đây', more: () => _select(4)),
      if (state.items('notifications').isEmpty)
        const Text('Bạn chưa có thông báo mới.'),
      ...state
          .items('notifications')
          .take(3)
          .map((n) => _notificationTile(n, state)),
      _section('Yêu cầu gần đây', more: () => _select(3)),
      if (state.items('requests').isEmpty)
        const Text('Bạn chưa gửi yêu cầu nào.'),
      ...state
          .items('requests')
          .take(3)
          .map(
            (r) => Card(
              child: ListTile(
                onTap: () => _select(3),
                title: Text(requestType(r['type'])),
                subtitle: Text(
                  '${BranchHelpers.formatIsoDate(r['startDate'])}\n${r['reason']}',
                ),
                trailing: StatusBadge.fromStatus('${r['status']}'),
              ),
            ),
          ),
    ]);
  }

  Widget _attendance(StaffState state) {
    final items = state.items('attendance').where((r) {
      final date = DateTime.tryParse('${r['date']}');
      if (_historyRange != null &&
          (date == null ||
              date.isBefore(_historyRange!.start) ||
              date.isAfter(_historyRange!.end))) {
        return false;
      }
      return switch (_attendanceFilter) {
        'LATE' => (r['lateMinutes'] as num? ?? 0) > 0,
        'EARLY' => (r['earlyLeaveMinutes'] as num? ?? 0) > 0,
        'OPEN' => r['checkOutTime'] == null,
        _ => true,
      };
    }).toList();
    return _list([
      PageHeading(
        title: 'Chấm công',
        subtitle: 'Giờ làm thực tế, đi muộn và về sớm',
        action: OutlinedButton.icon(
          onPressed: state.busy || state.loading
              ? null
              : () => _create(type: 'ATTENDANCE_CORRECTION'),
          icon: const Icon(Icons.edit_calendar_outlined),
          label: const Text('Quên / sửa chấm công'),
        ),
      ),
      ...state
          .items('today')
          .where((s) => s['status'] == 'PENDING' || s['status'] == 'CHECKED_IN')
          .map((s) => _shift(state, s)),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in {
            'ALL': 'Tất cả',
            'LATE': 'Đi muộn',
            'EARLY': 'Về sớm',
            'OPEN': 'Chưa ra ca',
          }.entries)
            ChoiceChip(
              label: Text(entry.value),
              selected: _attendanceFilter == entry.key,
              onSelected: (_) => setState(() => _attendanceFilter = entry.key),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange: _historyRange,
              );
              if (mounted && range != null) {
                setState(() => _historyRange = range);
              }
            },
            icon: const Icon(Icons.date_range),
            label: Text(
              _historyRange == null
                  ? 'Lọc theo ngày'
                  : '${BranchHelpers.prettyDate(_historyRange!.start)} – ${BranchHelpers.prettyDate(_historyRange!.end)}',
            ),
          ),
          if (_historyRange != null)
            TextButton(
              onPressed: () => setState(() => _historyRange = null),
              child: const Text('Bỏ lọc ngày'),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Text(
        '${items.length} bản ghi · ${minutesLabel(items.fold<num>(0, (sum, r) => sum + (r['workedMinutes'] as num? ?? 0)))} đã hoàn tất',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 16),
      if (items.isEmpty)
        const EmptyStateView(
          icon: Icons.history,
          title: 'Chưa có bản ghi phù hợp',
          message:
              'Chấm công ca hôm nay hoặc gửi đơn nếu bạn đã quên chấm công.',
        ),
      for (final r in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      '${r['shiftName']}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    StatusBadge.fromStatus('${r['status']}'),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${BranchHelpers.formatIsoDate(r['date'])} · ${r['storeName'] ?? '—'}',
                ),
                const SizedBox(height: 8),
                Text('Vào: ${stamp(r['checkInTime'])}'),
                Text(
                  'Ra: ${r['checkOutTime'] == null ? 'Chưa ra ca' : stamp(r['checkOutTime'])}',
                ),
                const SizedBox(height: 8),
                Text(
                  'Thực tế: ${r['checkOutTime'] == null ? 'Ca đang mở, chưa cộng giờ' : minutesLabel(r['workedMinutes'])}',
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if ((r['lateMinutes'] as num? ?? 0) > 0)
                      StatusBadge(
                        label: 'Đi muộn ${r['lateMinutes']} phút',
                        variant: BadgeVariant.warning,
                      ),
                    if ((r['earlyLeaveMinutes'] as num? ?? 0) > 0)
                      StatusBadge(
                        label: 'Về sớm ${r['earlyLeaveMinutes']} phút',
                        variant: BadgeVariant.warning,
                      ),
                    if (r['manuallyAdjusted'] == true)
                      const StatusBadge(
                        label: 'Đã điều chỉnh',
                        variant: BadgeVariant.info,
                      ),
                  ],
                ),
                TextButton.icon(
                  onPressed: state.busy || state.loading
                      ? null
                      : () => _create(
                          type: 'ATTENDANCE_CORRECTION',
                          scheduleId: r['scheduleId'] as int,
                        ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Yêu cầu sửa công'),
                ),
              ],
            ),
          ),
        ),
    ]);
  }

  Widget _notificationTile(StaffItem item, StaffState state) => Card(
    child: ListTile(
      leading: Icon(
        item['kind'] == 'ANNOUNCEMENT'
            ? Icons.campaign_outlined
            : Icons.notifications_outlined,
        color: item['read'] == true
            ? AppColors.textSecondary
            : AppColors.primary,
      ),
      title: Text(
        '${item['title']}',
        style: TextStyle(
          fontWeight: item['read'] == true ? FontWeight.w400 : FontWeight.w700,
        ),
      ),
      subtitle: Text(
        '${item['message']}\n${stamp(item['createdAt'])}',
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () async {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('${item['title']}'),
            content: SingleChildScrollView(
              child: Text('${item['message']}\n\n${stamp(item['createdAt'])}'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
        if (mounted && item['read'] != true) {
          await cubit.readNotification(item['id'] as int);
        }
      },
    ),
  );

  Widget _notifications(StaffState state) {
    final items = state
        .items('notifications')
        .where((n) => !_unreadOnly || n['read'] != true)
        .toList();
    return _list([
      PageHeading(
        title: 'Thông báo',
        subtitle: 'Lịch làm, nhắc giờ vào ca và phản hồi từ quản lý',
        action: TextButton.icon(
          onPressed: state.unread == 0 || state.loading || state.busy
              ? null
              : cubit.readAll,
          icon: const Icon(Icons.done_all),
          label: const Text('Đọc tất cả'),
        ),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Chỉ hiện chưa đọc'),
        value: _unreadOnly,
        onChanged: (v) => setState(() => _unreadOnly = v),
      ),
      if (items.isEmpty)
        const EmptyStateView(
          icon: Icons.notifications_none,
          title: 'Không có thông báo',
          message:
              'Thông báo phân ca và phản hồi yêu cầu sẽ xuất hiện tại đây.',
        ),
      ...items.map((n) => _notificationTile(n, state)),
    ]);
  }

  Widget _profile(StaffState state) {
    final p = state.profile;
    return _list([
      const PageHeading(
        title: 'Hồ sơ cá nhân',
        subtitle: 'Thông tin nhân viên và bảo mật tài khoản',
      ),
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
              '${p['name'] ?? '—'}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            const StatusBadge(
              label: 'Nhân viên',
              variant: BadgeVariant.neutral,
            ),
            const SizedBox(height: 16),
            for (final entry in {
              'Mã nhân viên': p['employeeCode'],
              'Số điện thoại đăng nhập': p['phone'],
              'Chi nhánh': p['storeName'],
              'Mã chi nhánh': p['storeCode'],
              'Email': p['email'],
              'Liên hệ khẩn cấp': p['emergencyContact'],
              'Địa chỉ': p['address'],
            }.entries)
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
                      entry.value == null || '${entry.value}'.isEmpty
                          ? 'Chưa cập nhật'
                          : '${entry.value}',
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: state.busy || state.loading
                      ? null
                      : () => _editProfile(),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Cập nhật thông tin'),
                ),
                OutlinedButton.icon(
                  onPressed: state.busy || state.loading
                      ? null
                      : () => _editProfile(password: true),
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Đổi mật khẩu'),
                ),
                TextButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Đăng xuất'),
                ),
              ],
            ),
          ],
        ),
      ),
    ]);
  }
}
