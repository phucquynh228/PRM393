package com.cafehr.attendance.service;

import com.cafehr.attendance.dto.AttendanceReportRow;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.schedule.entity.ScheduleStatus;
import com.cafehr.schedule.repository.UserScheduleRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import java.nio.charset.StandardCharsets;
import java.time.*;
import java.util.List;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AttendanceReportServiceTest {
    @Mock UserScheduleRepository schedules;
    @InjectMocks AttendanceReportService reports;

    AttendanceReportRow row(String name, ScheduleStatus status, LocalDateTime in, LocalDateTime out) {
        return new AttendanceReportRow(LocalDate.of(2024, 2, 29), 7L, 2L, name, "CN-01",
                "Chi nhánh cũ", "Ca đêm", LocalTime.of(22, 0), LocalTime.of(6, 0), status, in, out, false);
    }

    @ParameterizedTest
    @CsvSource({"day,2024-02-29,2024-02-29", "month,2024-02-01,2024-02-29",
            "year,2024-01-01,2024-12-31", "month,2023-02-01,2023-02-28"})
    void periodsIncludeEntireCalendarRange(String period, String from, String to) {
        when(schedules.findAttendanceReport(any(), any(), eq(2L), eq(3L)))
                .thenReturn(List.of(row("Nguyễn An", ScheduleStatus.PENDING, null, null)));
        String anchor = from.substring(0, 4) + "-02-" + (from.startsWith("2024") ? "29" : "28");
        var file = reports.export(period, anchor, 2L, 3L);
        verify(schedules).findAttendanceReport(LocalDate.parse(from), LocalDate.parse(to), 2L, 3L);
        assertEquals("bao-cao-cham-cong_" + from + "_" + to + "_nv-2_cn-3.csv", file.filename());
    }

    @Test void csvPreservesVietnameseEscapesCellsAndCountsOvernightMinutes() {
        LocalDateTime in = LocalDateTime.of(2024, 2, 29, 22, 0);
        when(schedules.findAttendanceReport(any(), any(), isNull(), isNull())).thenReturn(List.of(
                row("Nguyễn, \"An\"\nB", ScheduleStatus.CHECKED_OUT, in, in.plusHours(8)),
                row("  =HYPERLINK(\"x\")", ScheduleStatus.ABSENT, null, null),
                row("Đang làm", ScheduleStatus.CHECKED_IN, in, null)));
        byte[] bytes = reports.export("day", "2024-02-29", null, null).bytes();
        assertArrayEquals(new byte[]{(byte) 0xEF, (byte) 0xBB, (byte) 0xBF}, java.util.Arrays.copyOf(bytes, 3));
        String csv = new String(bytes, StandardCharsets.UTF_8);
        assertTrue(csv.contains("\"Nguyễn, \"\"An\"\"\nB\""));
        assertTrue(csv.contains("\"480\",\"Hoàn thành\""));
        assertTrue(csv.contains("\"'  =HYPERLINK(\"\"x\"\")\""));
        assertTrue(csv.contains("\"\",\"Vắng mặt\""));
        assertTrue(csv.contains("\"\",\"Đang làm\""));
    }

    @ParameterizedTest
    @CsvSource({"week,2024-02-29", "day,2023-02-29", "month,garbage", "year,1999-01-01", "day,2101-01-01"})
    void invalidPeriodOrDateNeverQueriesDatabase(String period, String date) {
        assertThrows(BusinessException.class, () -> reports.export(period, date, null, null));
        verifyNoInteractions(schedules);
    }

    @Test void invalidIdsAndEmptyResultsReturnActionableErrors() {
        assertThrows(BusinessException.class, () -> reports.export("day", "2024-02-29", -1L, null));
        verifyNoInteractions(schedules);
        when(schedules.findAttendanceReport(any(), any(), isNull(), isNull())).thenReturn(List.of());
        var error = assertThrows(BusinessException.class, () -> reports.export("year", "2024-01-01", null, null));
        assertTrue(error.getMessage().contains("Không có dữ liệu"));
        var empty = reports.snapshot("year", "2024-01-01", null, null).summary();
        assertEquals(0, empty.employeeCount()); assertTrue(empty.employees().isEmpty());
    }

    @Test void summaryCountsPeopleOnceAndSeparatesLateAbsencesAndLeave() {
        LocalDateTime start = LocalDateTime.of(2024, 2, 29, 22, 0);
        when(schedules.findAttendanceReport(any(), any(), isNull(), isNull())).thenReturn(List.of(
                row("Nguyễn An", ScheduleStatus.CHECKED_OUT, start.plusMinutes(1), start.plusHours(8)),
                row("Nguyễn An", ScheduleStatus.CHECKED_IN, start.plusSeconds(59), null),
                row("Nguyễn An", ScheduleStatus.ABSENT, null, null),
                row("Nguyễn An", ScheduleStatus.ON_LEAVE, null, null)));
        var summary = reports.snapshot("month", "2024-02-29", null, null).summary();
        assertEquals(1, summary.employeeCount()); assertEquals(1, summary.completedShifts());
        assertEquals(1, summary.lateShifts()); assertEquals(1, summary.unexcusedAbsences());
        assertEquals(1, summary.employees().get(0).completedShifts());
    }
}
