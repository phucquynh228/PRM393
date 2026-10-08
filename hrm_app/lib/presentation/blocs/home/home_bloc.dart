import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/usecases/get_schedules_usecase.dart';
import '../../../domain/usecases/check_in_usecase.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetSchedulesUseCase getSchedulesUseCase;
  final CheckInUseCase checkInUseCase;

  HomeBloc({
    required this.getSchedulesUseCase,
    required this.checkInUseCase,
  }) : super(HomeInitial()) {
    on<LoadSchedules>(_onLoadSchedules);
    on<CheckInRequested>(_onCheckInRequested);
    on<CheckOutRequested>(_onCheckOutRequested);
  }

  Future<void> _onLoadSchedules(
    LoadSchedules event,
    Emitter<HomeState> emit,
  ) async {
    emit(HomeLoading());
    try {
      final schedules = await getSchedulesUseCase();
      emit(HomeLoaded(schedules: schedules));
    } catch (e) {
      emit(HomeError(error: e.toString()));
    }
  }

  Future<void> _onCheckInRequested(
    CheckInRequested event,
    Emitter<HomeState> emit,
  ) async {
    emit(HomeLoading());
    try {
      await checkInUseCase(event.scheduleId);
      emit(const HomeActionSuccess(message: 'Chấm công thành công!'));
      add(LoadSchedules()); // Tải lại danh sách ca sau khi chấm công
    } catch (e) {
      emit(HomeError(error: e.toString()));
      add(LoadSchedules()); // Tải lại lịch
    }
  }

  Future<void> _onCheckOutRequested(
    CheckOutRequested event,
    Emitter<HomeState> emit,
  ) async {
    emit(HomeLoading());
    // TODO: Connect checkOutUsecase later if needed, currently API Spec only emphasizes Check-in.
    // For now we simulate success or throw not implemented.
    try {
      // await checkOutUseCase(event.attendanceId);
      emit(const HomeActionSuccess(message: 'Check-out thành công!'));
      add(LoadSchedules());
    } catch (e) {
      emit(HomeError(error: e.toString()));
      add(LoadSchedules());
    }
  }
}
