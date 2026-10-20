import '../../data/models/schedule_model.dart';
import '../../data/models/attendance_record.dart';

abstract class AttendanceRepository {
  Future<List<ScheduleModel>> getTodaySchedules();
  Future<List<AttendanceRecord>> getHistory();
  Future<void> checkIn(int? scheduleId);
  Future<void> checkOut(int attendanceId);
}
