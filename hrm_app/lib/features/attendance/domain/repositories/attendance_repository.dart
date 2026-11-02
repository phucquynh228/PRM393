import 'package:hrm_app/features/schedule/data/models/schedule_model.dart';
import 'package:hrm_app/features/attendance/data/models/attendance_record.dart';

abstract class AttendanceRepository {
  Future<List<ScheduleModel>> getTodaySchedules();
  Future<List<AttendanceRecord>> getHistory();
  Future<void> checkIn(int? scheduleId);
  Future<void> checkOut(int attendanceId);
}
