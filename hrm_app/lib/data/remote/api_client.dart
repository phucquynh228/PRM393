import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../models/api_response.dart';
import '../models/check_in_request.dart';
import '../models/login_request.dart';
import '../models/login_response.dart';
import '../models/schedule_model.dart';

part 'api_client.g.dart';

@RestApi()
abstract class ApiClient {
  factory ApiClient(Dio dio, {String baseUrl}) = _ApiClient;

  @POST('/auth/login')
  Future<ApiResponse<LoginResponse>> login(@Body() LoginRequest request);

  @GET('/schedules/today')
  Future<ApiResponse<List<ScheduleModel>>> getTodaySchedules();

  @POST('/attendance/check-in')
  Future<ApiResponse<dynamic>> checkIn(@Body() CheckInRequest request);

  @POST('/attendance/check-out/{attendanceId}')
  Future<ApiResponse<dynamic>> checkOut(@Path("attendanceId") int attendanceId);

  @POST('/auth/reset-device/{userId}')
  Future<ApiResponse<dynamic>> resetDevice(@Path("userId") int userId);
}
