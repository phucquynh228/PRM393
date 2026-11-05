import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:hrm_app/features/attendance/data/models/attendance_record.dart';
import 'package:hrm_app/features/schedule/data/models/schedule_model.dart';
import 'package:hrm_app/features/attendance/domain/repositories/attendance_repository.dart';

class FakeAttendanceRepository implements AttendanceRepository {
  List<ScheduleModel> schedules = [
    ScheduleModel(
      id: 7,
      shiftName: 'Ca sáng',
      startTime: '07:00',
      endTime: '12:00',
      status: 'CHECKED_IN',
    ),
  ];
  List<AttendanceRecord> history = [
    AttendanceRecord(
      id: 42,
      scheduleId: 7,
      shiftName: 'Ca sáng',
      status: 'CHECKED_IN',
      checkInTime: DateTime(2026, 10, 20, 7),
    ),
  ];
  final checkoutCalls = <int>[];
  bool failCheckout = false, failLoad = false;
  Completer<void>? checkoutGate;
  @override
  Future<List<ScheduleModel>> getTodaySchedules() async {
    if (failLoad) throw Exception('Không tải được dữ liệu');
    return schedules;
  }

  @override
  Future<List<AttendanceRecord>> getHistory() async => history;
  @override
  Future<void> checkIn(int? scheduleId) async {}
  @override
  Future<void> checkOut(int attendanceId) async {
    checkoutCalls.add(attendanceId);
    if (checkoutGate != null) await checkoutGate!.future;
    if (failCheckout) throw Exception('Máy chủ từ chối');
  }
}

typedef TestHandler = FutureOr<ResponseBody> Function(RequestOptions options);

class TestAdapter implements HttpClientAdapter {
  final TestHandler handler;
  TestAdapter(this.handler);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handler(options);
  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponse(
  Object? data, {
  int status = 200,
  bool success = true,
  String? message,
}) => ResponseBody.fromString(
  jsonEncode({'success': success, 'data': data, 'message': message}),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);
Dio testDio(TestHandler handler) =>
    Dio(BaseOptions(baseUrl: 'http://localhost/api'))
      ..httpClientAdapter = TestAdapter(handler);
