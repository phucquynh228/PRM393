const maxAttendanceDuration = Duration(hours: 24);

bool attendanceNeedsCorrection(Map<String, dynamic> record, {DateTime? now}) {
  if (record['needsCorrection'] == true) return true;
  final checkIn = DateTime.tryParse('${record['checkInTime']}');
  final checkOut = DateTime.tryParse('${record['checkOutTime']}');
  if (checkIn == null) return true;
  if (checkOut != null) {
    return !checkOut.isAfter(checkIn) ||
        checkOut.isAfter(checkIn.add(maxAttendanceDuration));
  }
  final current = now ?? DateTime.now();
  return current.isBefore(checkIn) ||
      current.isAfter(checkIn.add(maxAttendanceDuration));
}

bool attendanceCanCheckOut(Map<String, dynamic> record) =>
    record['checkOutTime'] == null &&
    record['canCheckOut'] != false &&
    !attendanceNeedsCorrection(record);
