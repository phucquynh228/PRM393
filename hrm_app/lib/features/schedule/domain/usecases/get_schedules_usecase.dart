import 'package:hrm_app/features/schedule/data/models/schedule_model.dart';
import 'package:hrm_app/features/attendance/domain/repositories/attendance_repository.dart';

class GetSchedulesUseCase {
  final AttendanceRepository repository;

  GetSchedulesUseCase(this.repository);

  Future<List<ScheduleModel>> call() {
    return repository.getTodaySchedules();
  }
}
