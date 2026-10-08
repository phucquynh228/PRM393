import '../../core/services/location_service.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../models/check_in_request.dart';
import '../models/schedule_model.dart';
import '../remote/api_client.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  final ApiClient apiClient;
  final LocationService locationService;

  AttendanceRepositoryImpl({
    required this.apiClient,
    required this.locationService,
  });

  @override
  Future<List<ScheduleModel>> getTodaySchedules() async {
    final response = await apiClient.getTodaySchedules();
    if (response.success == true && response.data != null) {
      return response.data!;
    } else {
      throw Exception(response.message ?? 'Không thể tải lịch làm việc');
    }
  }

  @override
  Future<void> checkIn(int? scheduleId) async {
    // 1. Get GPS coordinates (Will throw if mocked/fake GPS)
    final position = await locationService.getCurrentPosition();

    // 2. Call API Check-in
    final request = CheckInRequest(
      scheduleId: scheduleId,
      lat: position.latitude,
      lng: position.longitude,
    );
    
    final response = await apiClient.checkIn(request);
    if (response.success != true) {
      throw Exception(response.message ?? 'Chấm công thất bại');
    }
  }

  @override
  Future<void> checkOut(int attendanceId) async {
    final response = await apiClient.checkOut(attendanceId);
    if (response.success != true) {
      throw Exception(response.message ?? 'Check-out thất bại');
    }
  }
}
