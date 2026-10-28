package com.cafehr.attendance.dto;

import com.cafehr.schedule.entity.ScheduleStatus;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

/** One published assignment, including assignments without a check-in. */
public record AttendanceReportRow(
        LocalDate date, Long scheduleId, Long userId, String userName,
        String storeCode, String storeName, String shiftName,
        LocalTime startTime, LocalTime endTime, ScheduleStatus status,
        LocalDateTime checkInTime, LocalDateTime checkOutTime, Boolean manuallyAdjusted) {}
