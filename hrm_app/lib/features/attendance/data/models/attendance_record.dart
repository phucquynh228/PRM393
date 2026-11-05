import 'package:hrm_app/core/utils/attendance_timing.dart';

class AttendanceRecord {
  final int id, scheduleId;
  final String shiftName, status;
  final DateTime? checkInTime, checkOutTime;
  final bool needsCorrection;
  final bool? checkoutAllowed;
  const AttendanceRecord({
    required this.id,
    required this.scheduleId,
    required this.shiftName,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
    this.needsCorrection = false,
    this.checkoutAllowed,
  });
  bool get canCheckOut =>
      checkOutTime == null && checkoutAllowed != false && !requiresCorrection;
  bool get requiresCorrection =>
      needsCorrection ||
      attendanceNeedsCorrection({
        'checkInTime': checkInTime?.toIso8601String(),
        'checkOutTime': checkOutTime?.toIso8601String(),
      });
  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        id: (json['id'] as num).toInt(),
        scheduleId: (json['scheduleId'] as num).toInt(),
        shiftName: json['shiftName']?.toString() ?? 'Ca làm',
        status: json['status']?.toString() ?? 'UNKNOWN',
        checkInTime: DateTime.tryParse(json['checkInTime']?.toString() ?? ''),
        checkOutTime: DateTime.tryParse(json['checkOutTime']?.toString() ?? ''),
        needsCorrection: json['needsCorrection'] == true,
        checkoutAllowed: json['canCheckOut'] as bool?,
      );
}
