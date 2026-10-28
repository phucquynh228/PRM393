package com.cafehr.attendance.dto;

import java.time.LocalDate;
import java.util.List;

public record AttendanceReportSummary(
        String period, LocalDate from, LocalDate to, String scope, int employeeCount,
        long completedShifts, long lateShifts, long unexcusedAbsences,
        List<Employee> employees) {
    public record Employee(Long userId, String employeeCode, String userName,
                           long completedShifts, long lateShifts, long unexcusedAbsences) {}
}
