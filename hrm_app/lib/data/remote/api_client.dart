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

  @GET('/attendance/history')
  Future<ApiResponse<dynamic>> getAttendanceHistory();

  @POST('/attendance/check-in')
  Future<ApiResponse<dynamic>> checkIn(@Body() CheckInRequest request);

  @POST('/attendance/check-out/{attendanceId}')
  Future<ApiResponse<dynamic>> checkOut(@Path("attendanceId") int attendanceId);

  @POST('/auth/reset-device/{userId}')
  Future<ApiResponse<dynamic>> resetDevice(@Path("userId") int userId);

  @GET('/admin/dashboard')
  Future<ApiResponse<dynamic>> getDashboardSummary();

  @GET('/admin/stores')
  Future<ApiResponse<dynamic>> getAllStores();

  @POST('/admin/stores')
  Future<ApiResponse<dynamic>> createStore(@Body() Map<String, dynamic> body);

  @PUT('/admin/stores/{id}')
  Future<ApiResponse<dynamic>> updateStore(
    @Path("id") int id,
    @Body() Map<String, dynamic> body,
  );

  @DELETE('/admin/stores/{id}')
  Future<ApiResponse<dynamic>> deleteStore(@Path("id") int id);

  @GET('/admin/users')
  Future<ApiResponse<dynamic>> getAllUsers();

  @POST('/admin/users')
  Future<ApiResponse<dynamic>> createUser(@Body() Map<String, dynamic> body);

  @PUT('/admin/users/{id}')
  Future<ApiResponse<dynamic>> updateUser(
    @Path("id") int id,
    @Body() Map<String, dynamic> body,
  );

  @DELETE('/admin/users/{id}')
  Future<ApiResponse<dynamic>> deleteUser(@Path("id") int id);

  @GET('/admin/attendance')
  Future<ApiResponse<dynamic>> getAllAttendance();
}
