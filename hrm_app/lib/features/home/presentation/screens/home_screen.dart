import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/schedule/data/models/schedule_model.dart';
import 'package:hrm_app/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:hrm_app/features/attendance/domain/usecases/check_in_usecase.dart';
import 'package:hrm_app/features/attendance/domain/usecases/check_out_usecase.dart';
import 'package:hrm_app/features/schedule/domain/usecases/get_schedules_usecase.dart';
import 'package:hrm_app/features/attendance/domain/usecases/get_attendance_history_usecase.dart';
import 'package:hrm_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:hrm_app/features/home/presentation/bloc/home_event.dart';
import 'package:hrm_app/features/home/presentation/bloc/home_state.dart';
import 'package:hrm_app/shared/presentation/widgets/app_shell.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';
import 'package:hrm_app/shared/presentation/widgets/empty_state_view.dart';
import 'package:hrm_app/shared/presentation/widgets/status_badge.dart';
import 'package:hrm_app/features/branch/presentation/helpers/branch_helpers.dart';
import 'package:hrm_app/features/staff/presentation/screens/employee_requests_screen.dart';
import 'package:hrm_app/features/auth/presentation/screens/login_screen.dart';

/// Employee state is scoped to this route and disposed on logout.
class HomeScreen extends StatelessWidget {
  final String? name;
  final bool allowRequests;
  const HomeScreen({super.key, this.name, this.allowRequests = true});
  @override
  Widget build(BuildContext context) {
    final repository = context.read<AttendanceRepository>();
    return BlocProvider(
      create: (_) => HomeBloc(
        getSchedulesUseCase: GetSchedulesUseCase(repository),
        checkInUseCase: CheckInUseCase(repository),
        checkOutUseCase: CheckOutUseCase(repository),
        getAttendanceHistoryUseCase: GetAttendanceHistoryUseCase(repository),
      ),
      child: _EmployeeWorkspace(name: name, allowRequests: allowRequests),
    );
  }
}

class _EmployeeWorkspace extends StatefulWidget {
  final String? name;
  final bool allowRequests;
  const _EmployeeWorkspace({this.name, required this.allowRequests});
  @override
  State<_EmployeeWorkspace> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<_EmployeeWorkspace> {
  int _index = 0;
  bool _requestsVisited = false;
  @override
  void initState() {
    super.initState();
    context.read<HomeBloc>().add(LoadSchedules());
  }

  Future<void> _refresh() async {
    final bloc = context.read<HomeBloc>();
    if (bloc.state.loading || bloc.state.busy) return;
    final completed = bloc.stream.firstWhere(
      (state) => !state.loading,
      orElse: () => bloc.state,
    );
    bloc.add(LoadSchedules());
    await completed;
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn muốn kết thúc phiên làm việc này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await const FlutterSecureStorage().delete(key: 'jwt_token');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _select(int index) => setState(() {
    _index = index;
    if (index == 2) _requestsVisited = true;
  });

  @override
  Widget build(BuildContext context) => BlocConsumer<HomeBloc, HomeState>(
    listener: (context, state) {
      if (state.message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(state.message!)));
      }
    },
    builder: (context, state) => AppShell(
      title: 'HRM Cafe',
      subtitle: 'Không gian nhân viên',
      selectedIndex: _index,
      destinations: [
        const AppDestination('Hôm nay', Icons.wb_sunny_outlined),
        const AppDestination('Chấm công', Icons.history_rounded),
        if (widget.allowRequests)
          const AppDestination('Yêu cầu', Icons.mail_outline_rounded),
      ],
      onDestinationSelected: _select,
      onLogout: _logout,
      onRefresh: _index == 2 ? null : () => _refresh(),
      refreshing: state.loading,
      error: _index == 2 ? null : state.error,
      child: IndexedStack(
        index: _index,
        children: [
          _today(state),
          _history(state),
          _requestsVisited
              ? const EmployeeRequestsScreen()
              : const SizedBox.shrink(),
        ],
      ),
    ),
  );

  Widget _today(HomeState state) {
    final now = DateTime.now();
    final completed = state.schedules
        .where((s) => s.status == 'CHECKED_OUT')
        .length;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          PageHeading(
            title: widget.name == null
                ? 'Ngày làm việc của bạn'
                : 'Xin chào, ${widget.name}',
            subtitle:
                '${BranchHelpers.prettyDate(now)} · Chúc bạn một ca làm tốt lành',
          ),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HÔM NAY',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${state.schedules.length} ca được phân công',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Đã hoàn thành $completed ca. Lịch hiển thị sau khi quản lý công bố.',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (widget.allowRequests)
                      OutlinedButton.icon(
                        onPressed: () => _select(2),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Gửi yêu cầu'),
                      ),
                    TextButton.icon(
                      onPressed: () => _select(1),
                      icon: const Icon(Icons.history),
                      label: const Text('Lịch sử chấm công'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Ca làm hôm nay',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          if (!state.initialized && state.loading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.schedules.isEmpty)
            EmptyStateView(
              icon: Icons.free_breakfast_outlined,
              title: state.error == null
                  ? 'Hôm nay chưa có ca làm'
                  : 'Chưa tải được lịch làm',
              message: state.error == null
                  ? 'Bạn có thể nghỉ ngơi hoặc kiểm tra lại sau khi quản lý công bố lịch.'
                  : 'Bấm làm mới để thử kết nối lại.',
            )
          else
            ...state.schedules.map(
              (schedule) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _shiftCard(schedule, state),
              ),
            ),
          const SizedBox(height: 8),
          const InlineNotice(
            'Ứng dụng sẽ xin quyền và lấy vị trí khi bạn check-in. Kết quả xác nhận phạm vi được kiểm tra khi gửi chấm công.',
          ),
        ],
      ),
    );
  }

  Widget _shiftCard(ScheduleModel schedule, HomeState state) {
    final checkedIn = schedule.status == 'CHECKED_IN';
    final pending = schedule.status == 'PENDING';
    final record = state.openAttendance(schedule.resolvedId);
    final active = state.busy && state.activeScheduleId == schedule.resolvedId;
    final enabled = !state.busy && !state.loading && schedule.resolvedId > 0;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                schedule.shiftName ?? 'Ca làm',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              StatusBadge.fromStatus(schedule.status),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.schedule_outlined,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${schedule.startTime ?? '—'} – ${schedule.endTime ?? '—'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (pending || checkedIn)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: !enabled || (checkedIn && record == null)
                    ? null
                    : () {
                        context.read<HomeBloc>().add(
                          checkedIn
                              ? CheckOutRequested(attendanceId: record!.id)
                              : CheckInRequested(
                                  scheduleId: schedule.resolvedId,
                                ),
                        );
                      },
                icon: active
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        checkedIn ? Icons.logout_rounded : Icons.login_rounded,
                        size: 20,
                      ),
                label: Text(
                  active
                      ? 'Đang xử lý…'
                      : checkedIn
                      ? 'Check-out · Kết thúc ca'
                      : 'Check-in · Bắt đầu ca',
                ),
              ),
            ),
          if (checkedIn && record == null)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text(
                'Chưa tìm thấy bản ghi vào ca. Vui lòng làm mới.',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          if (!pending && !checkedIn)
            Text(
              schedule.status == 'CHECKED_OUT'
                  ? 'Ca làm đã hoàn thành. Cảm ơn bạn!'
                  : 'Ca này hiện không thể chấm công.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _history(HomeState state) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const PageHeading(
          title: 'Lịch sử chấm công',
          subtitle: 'Các lần vào ca và ra ca của bạn',
        ),
        if (state.attendance.isEmpty)
          const EmptyStateView(
            icon: Icons.history_toggle_off,
            title: 'Chưa có bản ghi',
            message: 'Lịch sử sẽ xuất hiện sau lần check-in đầu tiên.',
          )
        else
          ...state.attendance.map(
            (record) => Padding(
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
                          record.shiftName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        StatusBadge.fromStatus(record.status),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      record.checkInTime == null
                          ? '—'
                          : BranchHelpers.prettyDate(record.checkInTime!),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 24,
                      runSpacing: 8,
                      children: [
                        Text(
                          'Vào ca: ${BranchHelpers.clockTime(record.checkInTime)}',
                        ),
                        Text(
                          'Ra ca: ${record.checkOutTime == null ? 'Chưa ra ca' : BranchHelpers.clockTime(record.checkOutTime)}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
