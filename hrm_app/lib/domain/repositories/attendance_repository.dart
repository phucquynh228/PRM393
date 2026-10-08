import '../../data/models/schedule_model.dart';

abstract class AttendanceRepository {
  Future<List<ScheduleModel>> getTodaySchedules();
  Future<void> checkIn(int? scheduleId);
  Future<void> checkOut(int attendanceId);
}
