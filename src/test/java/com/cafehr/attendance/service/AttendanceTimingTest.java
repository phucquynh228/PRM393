package com.cafehr.attendance.service;

import com.cafehr.attendance.entity.Attendance;
import org.junit.jupiter.api.Test;
import java.time.LocalDateTime;
import static org.junit.jupiter.api.Assertions.*;

class AttendanceTimingTest {
    final LocalDateTime checkIn = LocalDateTime.of(2026, 10, 24, 7, 0);
    @Test void checkoutIsAllowedUpToExactly24HoursIncludingOvernight() {
        var record = Attendance.builder().checkInTime(checkIn).build();
        assertTrue(AttendanceTiming.canCheckOut(record, checkIn.plusHours(8)));
        assertTrue(AttendanceTiming.canCheckOut(record, checkIn.plusHours(24)));
        assertFalse(AttendanceTiming.canCheckOut(record, checkIn.plusHours(24).plusNanos(1)));
        assertFalse(AttendanceTiming.canCheckOut(record, checkIn.minusSeconds(1)));
        assertTrue(AttendanceTiming.needsCorrection(record, checkIn.plusDays(12)));
        assertEquals(0, AttendanceTiming.workedMinutes(record));
    }
    @Test void oldMultiDayCheckoutIsExcludedInsteadOfBeingCappedTo24Hours() {
        assertEquals(0, AttendanceTiming.workedMinutes(checkIn, checkIn.plusDays(12)));
        assertFalse(AttendanceTiming.validCompleted(checkIn, checkIn.plusDays(12)));
        assertEquals(1440, AttendanceTiming.workedMinutes(checkIn, checkIn.plusHours(24)));
        assertEquals(480, AttendanceTiming.workedMinutes(checkIn, checkIn.plusHours(8)));
        assertEquals(0, AttendanceTiming.workedMinutes(checkIn, checkIn.minusHours(1)));
    }
}
