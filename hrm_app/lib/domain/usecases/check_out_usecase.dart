import '../repositories/attendance_repository.dart';

class CheckOutUseCase {
  final AttendanceRepository repository;
  CheckOutUseCase(this.repository);
  Future<void> call(int attendanceId) {
    if (attendanceId <= 0) {
      throw ArgumentError('Không tìm thấy bản ghi chấm công hợp lệ');
    }
    return repository.checkOut(attendanceId);
  }
}
