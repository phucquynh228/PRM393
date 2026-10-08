import '../repositories/attendance_repository.dart';

class CheckInUseCase {
  final AttendanceRepository repository;

  CheckInUseCase(this.repository);

  Future<void> call(int? scheduleId) {
    return repository.checkIn(scheduleId);
  }
}
