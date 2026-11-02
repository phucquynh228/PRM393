import 'package:hrm_app/features/attendance/data/models/attendance_record.dart';
import 'package:hrm_app/features/attendance/domain/repositories/attendance_repository.dart';

class GetAttendanceHistoryUseCase {
  final AttendanceRepository repository;
  GetAttendanceHistoryUseCase(this.repository);
  Future<List<AttendanceRecord>> call() => repository.getHistory();
}
