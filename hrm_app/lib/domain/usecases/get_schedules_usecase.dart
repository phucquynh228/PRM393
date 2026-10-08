import '../../data/models/schedule_model.dart';
import '../repositories/attendance_repository.dart';

class GetSchedulesUseCase {
  final AttendanceRepository repository;

  GetSchedulesUseCase(this.repository);

  Future<List<ScheduleModel>> call() {
    return repository.getTodaySchedules();
  }
}
