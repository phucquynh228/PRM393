/// Uses check-in calendar date, so historical records never inflate today's cards.
List<Map<String, dynamic>> attendanceOnDate(
  List<dynamic> records,
  DateTime day,
) => records.whereType<Map>().map((r) => Map<String, dynamic>.from(r)).where((
  r,
) {
  final date = DateTime.tryParse(r['checkInTime']?.toString() ?? '');
  return date != null &&
      date.year == day.year &&
      date.month == day.month &&
      date.day == day.day;
}).toList();

List<Map<String, dynamic>> branchAttendanceRecords(Map<String, dynamic> data) {
  final raw = data['records'] ?? data['items'];
  return raw is List
      ? raw.whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList()
      : [];
}
