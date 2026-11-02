package com.cafehr.attendance.service;

import com.cafehr.attendance.entity.Attendance;
import com.cafehr.attendance.repository.AttendanceRepository;
import com.cafehr.branch.entity.Store;
import com.cafehr.branch.repository.StoreRepository;
import com.cafehr.schedule.entity.*;
import com.cafehr.schedule.repository.*;
import com.cafehr.user.entity.*;
import com.cafehr.user.repository.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfSystemProperty;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.annotation.Transactional;
import java.nio.charset.StandardCharsets;
import java.time.*;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;

/** Opt-in SQL Server coverage; all report fixtures roll back. */
@SpringBootTest(properties = {"spring.main.banner-mode=off", "spring.jpa.show-sql=false", "debug=false",
        "logging.level.org.springframework=ERROR", "logging.level.com.cafehr=ERROR", "logging.level.org.hibernate.SQL=ERROR"})
@Transactional
@EnabledIfSystemProperty(named = "attendance.report.integration", matches = "true")
class AttendanceReportIntegrationTest {
    @Autowired AttendanceReportService reports;
    @Autowired UserScheduleRepository schedules;
    @Autowired AttendanceRepository attendance;
    @Autowired UserRepository users;
    @Autowired StoreRepository stores;
    @Autowired ShiftRepository shifts;

    @Test void queryIncludesMissingAttendanceAndPreservesHistoricalBranchAcrossTransfer() {
        String key = UUID.randomUUID().toString().substring(0, 8);
        Store old = stores.save(Store.builder().code("R1-" + key).name("Chi nhánh báo cáo cũ")
                .latitude(10.0).longitude(106.0).allowedRadius(200).build());
        Store target = stores.save(Store.builder().code("R2-" + key).name("Chi nhánh mới")
                .latitude(10.0).longitude(106.0).allowedRadius(200).build());
        User user = users.save(User.builder().name("Nhân viên báo cáo").phone("R" + key)
                .password("test-password").role(Role.STAFF).store(old).build());
        Shift shift = shifts.save(Shift.builder().name("Ca đêm báo cáo")
                .startTime(LocalTime.of(22, 0)).endTime(LocalTime.of(6, 0)).build());
        LocalDate day = LocalDate.of(2040, 2, 29);
        UserSchedule completed = schedules.save(UserSchedule.builder().user(user).store(old).shift(shift)
                .date(day).status(ScheduleStatus.CHECKED_OUT).build());
        // Check-in after midnight still belongs to the assigned work date.
        attendance.save(Attendance.builder().user(user).schedule(completed)
                .checkInTime(day.plusDays(1).atStartOfDay()).checkOutTime(day.plusDays(1).atTime(6, 0)).build());
        schedules.save(UserSchedule.builder().user(user).store(old).shift(shift)
                .date(day.minusDays(1)).status(ScheduleStatus.ABSENT).build());
        schedules.save(UserSchedule.builder().user(user).store(old).shift(shift)
                .date(day.minusDays(2)).status(ScheduleStatus.PENDING).published(false).build());
        schedules.save(UserSchedule.builder().user(user).store(old).shift(shift)
                .date(day.minusDays(3)).status(ScheduleStatus.CANCELLED).build());
        schedules.save(UserSchedule.builder().user(user).store(old).shift(shift)
                .date(day.plusDays(1)).status(ScheduleStatus.PENDING).build());
        user.setStore(target); users.saveAndFlush(user);
        schedules.flush(); attendance.flush();

        var rows = schedules.findAttendanceReport(day.withDayOfMonth(1), day, user.getId(), old.getId());
        assertEquals(2, rows.size());
        assertNull(rows.get(0).checkInTime());
        assertEquals("Chi nhánh báo cáo cũ", rows.get(1).storeName());
        assertEquals(day, rows.get(1).date());
        assertTrue(schedules.findAttendanceReport(day, day, null, null).stream()
                .anyMatch(row -> row.scheduleId().equals(completed.getId())));
        assertTrue(schedules.findAttendanceReport(day.withDayOfMonth(1), day, user.getId(), target.getId()).isEmpty());
        String csv = new String(reports.export("month", day.toString(), user.getId(), old.getId()).bytes(), StandardCharsets.UTF_8);
        assertTrue(csv.contains("\"360\",\"Hoàn thành\""));
        assertTrue(csv.contains("Vắng mặt"));
        assertEquals(2, csv.lines().count() - 1);
        var summary = reports.snapshot("month", day.toString(), user.getId(), old.getId()).summary();
        assertEquals(1, summary.employeeCount()); assertEquals(1, summary.completedShifts());
        assertEquals(1, summary.lateShifts()); assertEquals(1, summary.unexcusedAbsences());
    }
}
