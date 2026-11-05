package com.cafehr.attendance.service;

import com.cafehr.attendance.entity.Attendance;
import java.time.Duration;
import java.time.LocalDateTime;

/** Shared limit for checkout, staff totals and exported attendance reports. */
public final class AttendanceTiming {
    public static final Duration MAX_DURATION = Duration.ofHours(24);
    private AttendanceTiming() {}

    public static boolean validCompleted(LocalDateTime in, LocalDateTime out) {
        return in != null && out != null && out.isAfter(in) && !out.isAfter(in.plus(MAX_DURATION));
    }
    public static boolean validCompleted(Attendance a) { return validCompleted(a.getCheckInTime(), a.getCheckOutTime()); }
    public static boolean canCheckOut(Attendance a, LocalDateTime now) {
        var in = a.getCheckInTime();
        return a.getCheckOutTime() == null && in != null && !now.isBefore(in) && !now.isAfter(in.plus(MAX_DURATION));
    }
    public static boolean needsCorrection(Attendance a, LocalDateTime now) {
        return a.getCheckOutTime() == null ? !canCheckOut(a, now) : !validCompleted(a);
    }
    public static long workedMinutes(LocalDateTime in, LocalDateTime out) {
        return validCompleted(in, out) ? Duration.between(in, out).toMinutes() : 0;
    }
    public static long workedMinutes(Attendance a) { return workedMinutes(a.getCheckInTime(), a.getCheckOutTime()); }
    public static String status(Attendance a) {
        return needsCorrection(a, LocalDateTime.now()) ? "NEEDS_CORRECTION"
                : a.getSchedule() == null || a.getSchedule().getStatus() == null ? "N/A" : a.getSchedule().getStatus().name();
    }
    public static LocalDateTime deadline(Attendance a) {
        return a.getCheckInTime() == null ? null : a.getCheckInTime().plus(MAX_DURATION);
    }
}
