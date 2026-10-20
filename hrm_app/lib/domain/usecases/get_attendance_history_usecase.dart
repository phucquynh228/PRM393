import '../../data/models/attendance_record.dart';
import '../repositories/attendance_repository.dart';

class GetAttendanceHistoryUseCase {
  final AttendanceRepository repository;
  GetAttendanceHistoryUseCase(this.repository);
  Future<List<AttendanceRecord>> call() => repository.getHistory();
}
