package com.cafehr.attendance.service;

import com.cafehr.attendance.entity.Attendance;
import com.cafehr.attendance.repository.AttendanceRepository;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.schedule.entity.*;
import com.cafehr.schedule.repository.UserScheduleRepository;
import com.cafehr.user.entity.User;
import com.cafehr.user.repository.UserRepository;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import java.time.*;
import java.util.Optional;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AttendanceServiceTest {
    @Mock AttendanceRepository attendanceRepository;
    @Mock UserRepository userRepository;
    @Mock UserScheduleRepository userScheduleRepository;
    @Mock EntityManager entityManager;
    @InjectMocks AttendanceService service;
    Attendance record;
    UserSchedule schedule;
    @BeforeEach void setup() {
        var user = User.builder().id(3L).build();
        schedule = UserSchedule.builder().id(7L).user(user).date(LocalDate.now().minusDays(1))
                .shift(Shift.builder().name("Ca đêm").startTime(LocalTime.of(22, 0)).endTime(LocalTime.of(6, 0)).build())
                .status(ScheduleStatus.CHECKED_IN).build();
        record = Attendance.builder().id(42L).user(user).schedule(schedule).checkInTime(LocalDateTime.now().minusHours(8)).build();
        when(attendanceRepository.findById(42L)).thenReturn(Optional.of(record));
    }
    @Test void oldCheckInCannotBeCheckedOutOrMutatePersistedData() {
        record.setCheckInTime(LocalDateTime.now().minusDays(12));
        var error = assertThrows(BusinessException.class, () -> service.checkOut(3L, 42L));
        assertTrue(error.getMessage().contains("24 giờ"));
        assertNull(record.getCheckOutTime()); assertEquals(ScheduleStatus.CHECKED_IN, schedule.getStatus());
        verify(attendanceRepository, never()).save(any()); verify(userScheduleRepository, never()).save(any());
    }
    @Test void validOvernightCheckoutStillWorks() {
        when(attendanceRepository.save(record)).thenReturn(record);
        var response = service.checkOut(3L, 42L);
        assertNotNull(record.getCheckOutTime()); assertEquals(ScheduleStatus.CHECKED_OUT, schedule.getStatus());
        assertTrue(response.getWorkedMinutes() >= 480 && response.getWorkedMinutes() <= 481);
        assertFalse(response.isNeedsCorrection());
    }
    @Test void ownerAndDuplicateChecksRemainEnforced() {
        assertThrows(BusinessException.class, () -> service.checkOut(99L, 42L));
        record.setCheckOutTime(LocalDateTime.now());
        assertThrows(BusinessException.class, () -> service.checkOut(3L, 42L));
        verify(attendanceRepository, never()).save(any());
    }
}
