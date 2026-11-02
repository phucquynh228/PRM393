import 'package:equatable/equatable.dart';

import 'package:hrm_app/features/attendance/data/models/attendance_record.dart';
import 'package:hrm_app/features/schedule/data/models/schedule_model.dart';

class HomeState extends Equatable {
  final List<ScheduleModel> schedules;
  final List<AttendanceRecord> attendance;
  final bool loading, busy, initialized;
  final int? activeScheduleId;
  final String? error, message;
  const HomeState({
    this.schedules = const [],
    this.attendance = const [],
    this.loading = false,
    this.busy = false,
    this.initialized = false,
    this.activeScheduleId,
    this.error,
    this.message,
  });

  AttendanceRecord? openAttendance(int scheduleId) {
    for (final item in attendance) {
      if (item.scheduleId == scheduleId && item.checkOutTime == null) {
        return item;
      }
    }
    return null;
  }

  HomeState copyWith({
    List<ScheduleModel>? schedules,
    List<AttendanceRecord>? attendance,
    bool? loading,
    bool? busy,
    bool? initialized,
    int? activeScheduleId,
    String? error,
    String? message,
  }) => HomeState(
    schedules: schedules ?? this.schedules,
    attendance: attendance ?? this.attendance,
    loading: loading ?? this.loading,
    busy: busy ?? this.busy,
    initialized: initialized ?? this.initialized,
    activeScheduleId: activeScheduleId,
    error: error,
    message: message,
  );
  @override
  List<Object?> get props => [
    schedules,
    attendance,
    loading,
    busy,
    initialized,
    activeScheduleId,
    error,
    message,
  ];
}
