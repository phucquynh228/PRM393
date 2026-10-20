import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_error.dart';

import '../../../data/models/attendance_record.dart';
import '../../../data/models/schedule_model.dart';
import '../../../domain/usecases/get_schedules_usecase.dart';
import '../../../domain/usecases/check_in_usecase.dart';
import '../../../domain/usecases/check_out_usecase.dart';
import '../../../domain/usecases/get_attendance_history_usecase.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetSchedulesUseCase getSchedulesUseCase;
  final CheckInUseCase checkInUseCase;
  final CheckOutUseCase checkOutUseCase;
  final GetAttendanceHistoryUseCase getAttendanceHistoryUseCase;
  HomeBloc({
    required this.getSchedulesUseCase,
    required this.checkInUseCase,
    required this.checkOutUseCase,
    required this.getAttendanceHistoryUseCase,
  }) : super(const HomeState()) {
    on<LoadSchedules>((event, emit) async {
      if (state.busy || state.loading) return;
      emit(state.copyWith(loading: true));
      await _reload(emit);
    });
    on<CheckInRequested>((event, emit) async {
      if (state.busy || state.loading) return;
      final id = event.scheduleId;
      if (id == null || id <= 0) {
        emit(
          state.copyWith(
            error: 'Không tìm thấy ca làm hợp lệ. Vui lòng làm mới.',
          ),
        );
        return;
      }
      await _act(emit, id, () => checkInUseCase(id), 'Đã chấm công vào ca.');
    });
    on<CheckOutRequested>((event, emit) async {
      if (state.busy || state.loading) return;
      final record = state.attendance
          .where((a) => a.id == event.attendanceId && a.checkOutTime == null)
          .firstOrNull;
      if (record == null) {
        emit(
          state.copyWith(
            error: 'Không tìm thấy ca đang làm. Vui lòng làm mới.',
          ),
        );
        return;
      }
      await _act(
        emit,
        record.scheduleId,
        () => checkOutUseCase(record.id),
        'Đã chấm công ra ca.',
      );
    });
  }
  Future<void> _reload(Emitter<HomeState> emit, {String? message}) async {
    if (emit.isDone) return;
    try {
      final data = await Future.wait<Object>([
        getSchedulesUseCase(),
        getAttendanceHistoryUseCase(),
      ]);
      if (emit.isDone) return;
      emit(
        state.copyWith(
          schedules: data[0] as List<ScheduleModel>,
          attendance: data[1] as List<AttendanceRecord>,
          loading: false,
          busy: false,
          initialized: true,
          message: message,
        ),
      );
    } catch (e) {
      if (emit.isDone) return;
      emit(
        state.copyWith(
          loading: false,
          busy: false,
          error: message == null
              ? readableApiError(e)
              : '$message Chưa tải lại được dữ liệu, hãy bấm làm mới.',
        ),
      );
    }
  }

  Future<void> _act(
    Emitter<HomeState> emit,
    int id,
    Future<void> Function() action,
    String message,
  ) async {
    emit(state.copyWith(busy: true, activeScheduleId: id));
    try {
      await action();
    } catch (e) {
      if (emit.isDone) return;
      emit(state.copyWith(busy: false, error: readableApiError(e)));
      return;
    }
    await _reload(emit, message: message);
  }
}
