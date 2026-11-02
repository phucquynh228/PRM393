import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:hrm_app/core/config/api_config.dart';

enum AttendanceReportPeriod {
  day('Ngày'),
  month('Tháng'),
  year('Năm');

  final String label;
  const AttendanceReportPeriod(this.label);
}

enum AttendanceReportFormat {
  excel('xlsx', MimeType.microsoftExcel),
  pdf('pdf', MimeType.pdf);

  final String extension;
  final MimeType mimeType;
  const AttendanceReportFormat(this.extension, this.mimeType);
}

class EmployeeAttendanceSummary {
  final String employeeCode, userName;
  final int completedShifts, lateShifts, unexcusedAbsences;
  EmployeeAttendanceSummary.fromJson(Map<String, dynamic> json)
    : employeeCode = json['employeeCode'] as String,
      userName = json['userName'] as String,
      completedShifts = (json['completedShifts'] as num).toInt(),
      lateShifts = (json['lateShifts'] as num).toInt(),
      unexcusedAbsences = (json['unexcusedAbsences'] as num).toInt();
}

class AttendanceReportSummary {
  final int employeeCount, completedShifts, lateShifts, unexcusedAbsences;
  final List<EmployeeAttendanceSummary> employees;
  AttendanceReportSummary.fromJson(Map<String, dynamic> json)
    : employeeCount = (json['employeeCount'] as num).toInt(),
      completedShifts = (json['completedShifts'] as num).toInt(),
      lateShifts = (json['lateShifts'] as num).toInt(),
      unexcusedAbsences = (json['unexcusedAbsences'] as num).toInt(),
      employees = (json['employees'] as List)
          .map(
            (row) => EmployeeAttendanceSummary.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
}

class AttendanceReportRequest {
  final AttendanceReportPeriod period;
  final DateTime date;
  final int? userId, storeId;

  const AttendanceReportRequest({
    required this.period,
    required this.date,
    this.userId,
    this.storeId,
  });

  DateTime get from => switch (period) {
    AttendanceReportPeriod.day => DateTime(date.year, date.month, date.day),
    AttendanceReportPeriod.month => DateTime(date.year, date.month),
    AttendanceReportPeriod.year => DateTime(date.year),
  };

  DateTime get to => switch (period) {
    AttendanceReportPeriod.day => from,
    AttendanceReportPeriod.month => DateTime(date.year, date.month + 1, 0),
    AttendanceReportPeriod.year => DateTime(date.year, 12, 31),
  };

  static String ymd(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> get query => {
    'period': period.name,
    'date': ymd(from),
    if (userId != null) 'userId': userId,
    if (storeId != null) 'storeId': storeId,
  };

  String get filename =>
      'bao-cao-cham-cong_${ymd(from)}_${ymd(to)}'
      '${userId == null ? '' : '_nv-$userId'}'
      '${storeId == null ? '' : '_cn-$storeId'}';

  String get label => switch (period) {
    AttendanceReportPeriod.day => 'Ngày ${date.day}/${date.month}/${date.year}',
    AttendanceReportPeriod.month => 'Tháng ${date.month}/${date.year}',
    AttendanceReportPeriod.year => 'Năm ${date.year}',
  };
}

typedef AttendanceReportSaver = Future<String?> Function(
  String name,
  Uint8List bytes,
  AttendanceReportFormat format,
);

class AttendanceReportExporter {
  final Dio dio;
  final AttendanceReportSaver save;

  AttendanceReportExporter(this.dio, {AttendanceReportSaver? save})
    : save = save ?? _save;

  static Future<String?> _save(
    String name,
    Uint8List bytes,
    AttendanceReportFormat format,
  ) {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return FileSaver.instance.saveAs(
        name: name,
        bytes: bytes,
        ext: format.extension,
        mimeType: format.mimeType,
      );
    }
    return FileSaver.instance.saveFile(
      name: name,
      bytes: bytes,
      ext: format.extension,
      mimeType: format.mimeType,
    );
  }

  Future<AttendanceReportSummary> loadSummary(
    AttendanceReportRequest request,
  ) async {
    final response = await dio.get<Map<String, dynamic>>(
      '$globalBaseUrl/admin/attendance/report',
      queryParameters: request.query,
    );
    final body = response.data;
    if (body == null || body['success'] != true || body['data'] is! Map) {
      throw Exception(body?['message'] ?? 'Không tải được báo cáo chấm công.');
    }
    return AttendanceReportSummary.fromJson(
      Map<String, dynamic>.from(body['data'] as Map),
    );
  }

  Future<bool> export(
    AttendanceReportRequest request, {
    AttendanceReportFormat format = AttendanceReportFormat.excel,
  }) async {
    Response<List<int>> response;
    try {
      response = await dio.get<List<int>>(
        '$globalBaseUrl/admin/attendance/export',
        queryParameters: {...request.query, 'format': format.extension},
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
    } on DioException catch (error) {
      // Dio returns error JSON as bytes too when ResponseType.bytes is used.
      final bytes = error.response?.data;
      if (bytes is List<int>) {
        Object? body;
        try {
          body = jsonDecode(utf8.decode(bytes));
        } on FormatException {
          // Keep the original HTTP error when the response is not JSON.
        }
        if (body is Map && body['message'] is String) {
          throw Exception(body['message']);
        }
      }
      rethrow;
    }
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw Exception('Báo cáo không có nội dung. Vui lòng thử lại.');
    }
    return await save(request.filename, Uint8List.fromList(bytes), format) !=
        null;
  }
}
