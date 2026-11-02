package com.cafehr.staff.service;

import com.cafehr.attendance.entity.Attendance;
import com.cafehr.attendance.repository.AttendanceRepository;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.notification.repository.StaffNotificationRepository;
import com.cafehr.schedule.entity.ScheduleStatus;
import com.cafehr.schedule.entity.Shift;
import com.cafehr.schedule.entity.UserSchedule;
import com.cafehr.schedule.repository.UserScheduleRepository;
import com.cafehr.staff.dto.PasswordChangeRequest;
import com.cafehr.staff.repository.BranchRequestRepository;
import com.cafehr.staff.view.StaffViews;
import com.cafehr.user.entity.Role;
import com.cafehr.user.entity.User;
import com.cafehr.user.repository.UserRepository;

import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;
import java.time.*;
import java.time.temporal.TemporalAdjusters;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class StaffWorkspaceServiceTest {
    @Mock UserRepository users;
    @Mock UserScheduleRepository schedules;
    @Mock AttendanceRepository attendance;
    @Mock BranchRequestRepository requests;
    @Mock StaffNotificationRepository notifications;
    @Mock PasswordEncoder passwords;
    @InjectMocks StaffWorkspaceService service;

    @Test void weeklyHoursClipCrossMidnightRecordsAndExcludeOpenRecords() {
        LocalDate monday = LocalDate.now().with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
        User user = User.builder().id(3L).name("Nhân viên").role(Role.STAFF).build();
        UserSchedule shift = UserSchedule.builder().id(10L).user(user).date(monday.minusDays(1)).status(ScheduleStatus.CHECKED_OUT)
                .shift(Shift.builder().name("Ca đêm").startTime(LocalTime.of(22, 0)).endTime(LocalTime.of(6, 0)).build()).build();
        Attendance completed = Attendance.builder().id(1L).user(user).schedule(shift)
                .checkInTime(monday.minusDays(1).atTime(22, 0)).checkOutTime(monday.atTime(6, 0)).build();
        Attendance open = Attendance.builder().id(2L).user(user).schedule(shift).checkInTime(monday.atTime(8, 0)).build();
        when(users.findById(3L)).thenReturn(Optional.of(user));
        when(attendance.findByUserIdOrderByCheckInTimeDesc(3L)).thenReturn(List.of(completed, open));
        Map<String, Object> result = service.workspace(3L, monday, monday.plusDays(6));
        assertEquals(360L, result.get("weekWorkedMinutes"));
    }
    @Test void attendanceShowsLateEarlyAndActualMinutes() {
        User user = User.builder().id(3L).name("Staff").role(Role.STAFF).build();
        LocalDate day = LocalDate.now().minusDays(1);
        UserSchedule shift = UserSchedule.builder().id(10L).user(user).date(day).status(ScheduleStatus.CHECKED_OUT)
                .shift(Shift.builder().name("Ca sáng").startTime(LocalTime.of(7, 0)).endTime(LocalTime.of(12, 0)).build()).build();
        Map<String, Object> view = StaffViews.attendance(Attendance.builder().id(1L).user(user).schedule(shift)
                .checkInTime(day.atTime(7, 10)).checkOutTime(day.atTime(11, 45)).build());
        assertEquals(10L, view.get("lateMinutes")); assertEquals(15L, view.get("earlyLeaveMinutes"));
        assertEquals(275L, view.get("workedMinutes"));
    }
    @Test void cannotReadAnotherUsersNotification() {
        when(users.findById(3L)).thenReturn(Optional.of(User.builder().id(3L).role(Role.STAFF).build()));
        assertThrows(BusinessException.class, () -> service.markRead(3L, 99L));
        verify(notifications).findByIdAndUserId(99L, 3L);
    }
    @Test void passwordChangeChecksCurrentPassword() {
        User user = User.builder().id(3L).role(Role.STAFF).password("encoded").build();
        when(users.findById(3L)).thenReturn(Optional.of(user));
        PasswordChangeRequest body = new PasswordChangeRequest(); body.setCurrentPassword("wrong"); body.setNewPassword("new123456");
        assertThrows(BusinessException.class, () -> service.changePassword(3L, body));
        assertEquals("encoded", user.getPassword());
        verify(passwords, never()).encode(anyString());
    }
    @Test void nonStaffCannotUseWorkspaceService() {
        when(users.findById(1L)).thenReturn(Optional.of(User.builder().id(1L).role(Role.ADMIN).build()));
        assertThrows(BusinessException.class, () -> service.staff(1L));
    }
}
