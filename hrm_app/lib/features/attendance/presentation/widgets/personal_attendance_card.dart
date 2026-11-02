import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:hrm_app/core/theme/app_theme.dart';
import 'package:hrm_app/features/attendance/domain/repositories/attendance_repository.dart';
import 'package:hrm_app/features/attendance/domain/usecases/check_in_usecase.dart';
import 'package:hrm_app/features/attendance/domain/usecases/check_out_usecase.dart';
import 'package:hrm_app/features/schedule/domain/usecases/get_schedules_usecase.dart';
import 'package:hrm_app/features/attendance/domain/usecases/get_attendance_history_usecase.dart';
import 'package:hrm_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:hrm_app/features/home/presentation/bloc/home_event.dart';
import 'package:hrm_app/features/home/presentation/bloc/home_state.dart';
import 'package:hrm_app/features/home/presentation/screens/home_screen.dart';
import 'package:hrm_app/shared/presentation/widgets/content_widgets.dart';
import 'package:hrm_app/shared/presentation/widgets/status_badge.dart';

/// The same attendance flow as the employee route, scoped to the management dashboard.
class PersonalAttendanceCard extends StatelessWidget {
  final String name;
  final VoidCallback onChanged;
  const PersonalAttendanceCard({
    super.key,
    required this.name,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final repo = context.read<AttendanceRepository>();
    return BlocProvider(
      create: (_) => HomeBloc(
        getSchedulesUseCase: GetSchedulesUseCase(repo),
        checkInUseCase: CheckInUseCase(repo),
        checkOutUseCase: CheckOutUseCase(repo),
        getAttendanceHistoryUseCase: GetAttendanceHistoryUseCase(repo),
      )..add(LoadSchedules()),
      child: _AttendanceCard(name: name, onChanged: onChanged),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final String name;
  final VoidCallback onChanged;
  const _AttendanceCard({required this.name, required this.onChanged});
  @override
  Widget build(BuildContext context) => BlocConsumer<HomeBloc, HomeState>(
    listener: (context, state) {
      if (state.message != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(state.message!)));
        onChanged();
      }
    },
    builder: (context, state) => Card(
      color: AppColors.primarySubtle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.primary.withValues(alpha: .2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.fingerprint, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Chấm công của tôi',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      Text(name, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Làm mới chấm công cá nhân',
                  onPressed: state.loading || state.busy
                      ? null
                      : () => context.read<HomeBloc>().add(LoadSchedules()),
                  icon: const Icon(Icons.refresh, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (state.loading)
              const LinearProgressIndicator(color: AppColors.primary),
            if (state.error != null) ...[
              InlineNotice(state.error!, error: true),
              const SizedBox(height: 12),
            ],
            if (state.initialized && state.schedules.isEmpty) ...[
              const Text(
                'Hôm nay bạn chưa có ca được công bố.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ca làm sẽ xuất hiện tại đây khi được phân công.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
            for (final schedule in state.schedules) ...[
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  Text(
                    schedule.shiftName ?? 'Ca làm',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  StatusBadge.fromStatus(schedule.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${schedule.startTime ?? '—'} – ${schedule.endTime ?? '—'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              if (schedule.status == 'PENDING' ||
                  schedule.status == 'CHECKED_IN')
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed:
                      state.loading ||
                          state.busy ||
                          schedule.resolvedId <= 0 ||
                          (schedule.status == 'CHECKED_IN' &&
                              state.openAttendance(schedule.resolvedId) == null)
                      ? null
                      : () {
                          final event = schedule.status == 'CHECKED_IN'
                              ? CheckOutRequested(
                                  attendanceId: state
                                      .openAttendance(schedule.resolvedId)!
                                      .id,
                                )
                              : CheckInRequested(
                                  scheduleId: schedule.resolvedId,
                                );
                          context.read<HomeBloc>().add(event);
                        },
                  icon: Icon(
                    schedule.status == 'CHECKED_IN'
                        ? Icons.logout_rounded
                        : Icons.login_rounded,
                    size: 20,
                  ),
                  label: Text(
                    state.busy && state.activeScheduleId == schedule.resolvedId
                        ? 'Đang xử lý…'
                        : schedule.status == 'CHECKED_IN'
                        ? 'Check-out ngay'
                        : 'Check-in ngay',
                  ),
                ),
              if (schedule.status == 'CHECKED_IN' &&
                  state.openAttendance(schedule.resolvedId) == null)
                const Text(
                  'Chưa tìm thấy bản ghi vào ca. Hãy làm mới.',
                  style: TextStyle(color: AppColors.error, fontSize: 12),
                ),
              const SizedBox(height: 16),
            ],
            if (state.schedules.any((s) => s.status == 'PENDING'))
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Check-in cần quyền vị trí và có mặt trong phạm vi của quán.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: state.busy
                  ? null
                  : () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              HomeScreen(name: name, allowRequests: false),
                        ),
                      );
                      if (context.mounted) {
                        context.read<HomeBloc>().add(LoadSchedules());
                        onChanged();
                      }
                    },
              icon: const Icon(Icons.history, size: 18),
              label: const Text('Lịch sử & ca làm cá nhân'),
            ),
          ],
        ),
      ),
    ),
  );
}
