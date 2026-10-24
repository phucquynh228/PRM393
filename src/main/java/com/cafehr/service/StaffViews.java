package com.cafehr.service;

import com.cafehr.entity.*;
import java.time.*;
import java.util.LinkedHashMap;
import java.util.Map;

public final class StaffViews {
    private StaffViews() {}

    public static Map<String, Object> row(Object... pairs) {
        Map<String, Object> result = new LinkedHashMap<>();
        for (int i = 0; i < pairs.length; i += 2) result.put((String) pairs[i], pairs[i + 1]);
        return result;
    }

    public static Map<String, Object> profile(User user) {
        Store store = user.getStore();
        return row("id", user.getId(), "employeeCode", "NV-" + String.format("%04d", user.getId()),
                "name", user.getName(), "phone", user.getPhone(), "role", user.getRole().name(),
                "email", user.getEmail(), "address", user.getAddress(), "emergencyContact", user.getEmergencyContact(),
                "storeId", store == null ? null : store.getId(), "storeName", store == null ? null : store.getName(),
                "storeCode", store == null ? null : store.getCode());
    }

    public static LocalDateTime start(UserSchedule schedule) {
        return schedule.getDate().atTime(schedule.getShift().getStartTime());
    }

    public static LocalDateTime end(UserSchedule schedule) {
        LocalDateTime end = schedule.getDate().atTime(schedule.getShift().getEndTime());
        return end.isAfter(start(schedule)) ? end : end.plusDays(1);
    }

    public static Map<String, Object> schedule(UserSchedule schedule) {
        Store store = schedule.getUser().getStore();
        return row("id", schedule.getId(), "scheduleId", schedule.getId(), "userId", schedule.getUser().getId(),
                "userName", schedule.getUser().getName(), "shiftName", schedule.getShift().getName(),
                "shiftId", schedule.getShift().getId(), "date", schedule.getDate(),
                "startTime", schedule.getShift().getStartTime(), "endTime", schedule.getShift().getEndTime(),
                "startsAt", start(schedule), "endsAt", end(schedule), "status", schedule.getStatus().name(),
                "storeName", store == null ? null : store.getName(), "storeCode", store == null ? null : store.getCode(),
                "storeId", store == null ? null : store.getId(), "published", schedule.isPublished(),
                "breakMinutes", schedule.getShift().getBreakMinutes());
    }

    public static Map<String, Object> attendance(Attendance attendance) {
        UserSchedule schedule = attendance.getSchedule();
        LocalDateTime checkOut = attendance.getCheckOutTime();
        return row("id", attendance.getId(), "scheduleId", schedule.getId(), "date", schedule.getDate(),
                "shiftName", schedule.getShift().getName(), "storeName", schedule.getUser().getStore() == null
                        ? null : schedule.getUser().getStore().getName(),
                "checkInTime", attendance.getCheckInTime(), "checkOutTime", checkOut,
                "status", schedule.getStatus().name(), "manuallyAdjusted", attendance.isManuallyAdjusted(),
                "workedMinutes", checkOut == null ? 0 : Math.max(0, Duration.between(attendance.getCheckInTime(), checkOut).toMinutes()),
                "lateMinutes", Math.max(0, Duration.between(start(schedule), attendance.getCheckInTime()).toMinutes()),
                "earlyLeaveMinutes", checkOut == null ? 0 : Math.max(0, Duration.between(checkOut, end(schedule)).toMinutes()));
    }

    public static boolean canCancel(BranchRequest request) {
        return request.getStatus() == BranchRequestStatus.PENDING
                && (request.getType() == BranchRequestType.ATTENDANCE_CORRECTION
                    || !request.getStartDate().isBefore(LocalDate.now()));
    }

    public static Map<String, Object> request(BranchRequest request) {
        return row("id", request.getId(), "userId", request.getUser().getId(), "userName", request.getUser().getName(),
                "type", request.getType().name(), "startDate", request.getStartDate(), "endDate", request.getEndDate(),
                "reason", request.getReason(), "status", request.getStatus().name(), "managerNote", request.getManagerNote(),
                "createdAt", request.getCreatedAt(), "sourceScheduleId", request.getSourceScheduleId(),
                "targetScheduleId", request.getTargetScheduleId(), "requestedCheckIn", request.getRequestedCheckIn(),
                "requestedCheckOut", request.getRequestedCheckOut(), "canCancel", canCancel(request));
    }

    public static Map<String, Object> notification(StaffNotification item) {
        return row("id", item.getId(), "title", item.getTitle(), "message", item.getMessage(),
                "kind", item.getKind(), "createdAt", item.getCreatedAt(), "read", item.getReadAt() != null);
    }
}
