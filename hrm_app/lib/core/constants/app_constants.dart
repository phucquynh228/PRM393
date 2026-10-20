class AppConstants {
  // Trạng thái Ca làm việc
  static const String shiftStatusPending = 'PENDING';
  static const String shiftStatusInProgress = 'IN_PROGRESS';
  static const String shiftStatusCompleted = 'COMPLETED';
  static const String shiftStatusCanceled = 'CANCELED';

  // Trạng thái Yêu cầu (Nghỉ phép / Đổi ca)
  static const String requestStatusPending = 'PENDING';
  static const String requestStatusApproved = 'APPROVED';
  static const String requestStatusRejected = 'REJECTED';
  static const String requestStatusCanceled = 'CANCELED';

  // Trạng thái Chấm công
  static const String attendanceStatusCheckedIn = 'CHECKED_IN';
  static const String attendanceStatusCheckedOut = 'CHECKED_OUT';
  static const String attendanceStatusLate = 'LATE';
  static const String attendanceStatusEarlyLeave = 'EARLY_LEAVE';
  static const String attendanceStatusMissingCheckout = 'MISSING_CHECKOUT';
}
