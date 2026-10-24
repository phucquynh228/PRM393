class AttendanceRecord {
  final int id, scheduleId;
  final String shiftName, status;
  final DateTime? checkInTime, checkOutTime;
  const AttendanceRecord({
    required this.id,
    required this.scheduleId,
    required this.shiftName,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
  });
  factory AttendanceRecord.fromJson(Map<String, dynamic> json) =>
      AttendanceRecord(
        id: (json['id'] as num).toInt(),
        scheduleId: (json['scheduleId'] as num).toInt(),
        shiftName: json['shiftName']?.toString() ?? 'Ca làm',
        status: json['status']?.toString() ?? 'UNKNOWN',
        checkInTime: DateTime.tryParse(json['checkInTime']?.toString() ?? ''),
        checkOutTime: DateTime.tryParse(json['checkOutTime']?.toString() ?? ''),
      );
}
