import 'package:dio/dio.dart';

import '../../core/services/location_service.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../models/check_in_request.dart';
import '../models/attendance_record.dart';
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
  Future<List<AttendanceRecord>> getHistory() async {
    final response = await apiClient.getAttendanceHistory();
    if (response.success != true || response.data is! List) {
      throw Exception(response.message ?? 'Không tải được lịch sử chấm công');
    }
    return (response.data as List)
        .map(
          (item) =>
              AttendanceRecord.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList()
      ..sort(
        (a, b) => (b.checkInTime ?? DateTime(1970)).compareTo(
          a.checkInTime ?? DateTime(1970),
        ),
      );
  }

  @override
  Future<List<ScheduleModel>> getTodaySchedules() async {
    try {
      final response = await apiClient.getTodaySchedules();
      if (response.success == true && response.data != null) {
        return response.data!;
      } else {
        throw Exception(response.message ?? 'Unable to load work schedules');
      }
    } on DioException catch (e) {
      if (e.response?.data != null && e.response?.data is Map) {
        final message = e.response?.data['message'];
        if (message != null && message.toString().isNotEmpty) {
          throw Exception(message.toString());
        }
      }
      rethrow;
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

    try {
      final response = await apiClient.checkIn(request);
      if (response.success != true) {
        throw Exception(response.message ?? 'Check-in failed');
      }
    } on DioException catch (e) {
      if (e.response?.data != null && e.response?.data is Map) {
        final message = e.response?.data['message'];
        if (message != null && message.toString().isNotEmpty) {
          throw Exception(message.toString());
        }
      }
      rethrow;
    }
  }

  @override
  Future<void> checkOut(int attendanceId) async {
    try {
      final response = await apiClient.checkOut(attendanceId);
      if (response.success != true) {
        throw Exception(response.message ?? 'Check-out failed');
      }
    } on DioException catch (e) {
      if (e.response?.data != null && e.response?.data is Map) {
        final message = e.response?.data['message'];
        if (message != null && message.toString().isNotEmpty) {
          throw Exception(message.toString());
        }
      }
      rethrow;
    }
  }
}
