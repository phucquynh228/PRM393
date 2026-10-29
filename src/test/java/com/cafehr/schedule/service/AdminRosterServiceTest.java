package com.cafehr.schedule.service;

import com.cafehr.attendance.entity.Attendance;
import com.cafehr.attendance.repository.AttendanceRepository;
import com.cafehr.branch.entity.*;
import com.cafehr.branch.repository.StoreRepository;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.notification.service.StaffNotificationService;
import com.cafehr.schedule.entity.*;
import com.cafehr.schedule.repository.UserScheduleRepository;
import com.cafehr.staff.entity.BranchRequest;
import com.cafehr.staff.repository.BranchRequestRepository;
import com.cafehr.staff.service.StaffRequestService;
import com.cafehr.user.entity.*;
import com.cafehr.user.repository.UserRepository;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import java.time.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class) @MockitoSettings(strictness = Strictness.LENIENT)
class AdminRosterServiceTest {
    @Mock UserScheduleRepository schedules;
    @Mock StoreRepository stores;
    @Mock UserRepository users;
    @Mock AttendanceRepository attendance;
    @Mock BranchRequestRepository requests;
    @Mock StaffRequestService leave;
    @Mock StaffNotificationService notifications;
    @Mock EntityManager em;
    AdminRosterService service;
    Store home, target;
    User user;
    UserSchedule assignment;

    @BeforeEach void fixture() {
        home = Store.builder().id(1L).code("A").name("Chi nhánh A").build();
        target = Store.builder().id(2L).code("B").name("Chi nhánh B").build();
        user = User.builder().id(3L).name("Lan").role(Role.STAFF).store(home).build();
        assignment = UserSchedule.builder().id(4L).user(user).store(home).storeName(home.getName()).storeCode(home.getCode())
                .date(LocalDate.now().plusDays(5)).shiftSlot(ShiftSlot.MORNING).published(true)
                .status(ScheduleStatus.PENDING).shift(Shift.builder().id(5L).name("Ca sáng")
                        .startTime(LocalTime.of(8, 0)).endTime(LocalTime.of(12, 0)).build()).build();
        when(schedules.findById(4L)).thenReturn(Optional.of(assignment));
        when(schedules.findLockedById(4L)).thenReturn(Optional.of(assignment));
        when(stores.findLockedById(1L)).thenReturn(Optional.of(home));
        when(stores.findLockedById(2L)).thenReturn(Optional.of(target));
        when(users.findLockedById(3L)).thenReturn(Optional.of(user));
        when(schedules.findByUserIdAndDateBetweenOrderByDateAscShiftStartTimeAsc(any(), any(), any())).thenReturn(List.of(assignment));
        service = new AdminRosterService(schedules, stores, users, attendance, requests, leave,
                new ScheduleRules(schedules), notifications, em);
    }

    @Test void transfersOnlyAssignmentAndUpdatesSnapshot() {
        LocalDate date = assignment.getDate(); Shift shift = assignment.getShift();
        var response = service.transfer(4L, 1L, 2L);
        assertSame(home, user.getStore()); assertSame(target, assignment.getStore());
        assertEquals(date, assignment.getDate()); assertSame(shift, assignment.getShift());
        assertEquals(ShiftSlot.MORNING, assignment.getShiftSlot());
        assertTrue(assignment.isPublished()); assertTrue(assignment.isTemporaryTransfer());
        assertEquals("Chi nhánh B", response.get("storeName")); assertEquals("B", response.get("storeCode"));
        verify(leave).assertNoLeave(3L, date);
        verify(notifications).scheduleChanged(eq(assignment), contains("Chi nhánh B"));
    }

    @Test void draftStaysDraftAndCanBeReturnedHome() {
        assignment.setPublished(false);
        service.transfer(4L, 1L, 2L);
        assertFalse(assignment.isPublished());
        service.transfer(4L, 2L, 1L);
        assertFalse(assignment.isTemporaryTransfer()); assertSame(home, assignment.getStore());
    }

    @Test void staleSourceAndSameBranchAreRejected() {
        assertThrows(BusinessException.class, () -> service.transfer(4L, 2L, 1L));
        assertThrows(BusinessException.class, () -> service.transfer(4L, 1L, 1L));
        assertSame(home, assignment.getStore()); verifyNoInteractions(notifications);
    }

    @Test void closedTargetAndInactiveEmployeeAreRejected() {
        target.setStatus(StoreStatus.CLOSED);
        assertThrows(BusinessException.class, () -> service.transfer(4L, 1L, 2L));
        target.setStatus(StoreStatus.ACTIVE); user.setEmploymentStatus(EmploymentStatus.INACTIVE);
        assertThrows(BusinessException.class, () -> service.transfer(4L, 1L, 2L));
        verifyNoInteractions(notifications);
    }

    @Test void startedCancelledLeaveAndAttendanceCannotBeTransferred() {
        assignment.setDate(LocalDate.now().minusDays(1));
        assertThrows(BusinessException.class, () -> service.transfer(4L, 1L, 2L));
        assignment.setDate(LocalDate.now().plusDays(5));
        for (var status : List.of(ScheduleStatus.CANCELLED, ScheduleStatus.ON_LEAVE, ScheduleStatus.CHECKED_IN)) {
            assignment.setStatus(status);
            assertThrows(BusinessException.class, () -> service.transfer(4L, 1L, 2L));
        }
        assignment.setStatus(ScheduleStatus.PENDING);
        when(attendance.findByScheduleId(4L)).thenReturn(Optional.of(new Attendance()));
        assertThrows(BusinessException.class, () -> service.transfer(4L, 1L, 2L));
        verifyNoInteractions(notifications);
    }

    @Test void pendingSwapAndApprovedLeaveBlockTransfer() {
        var pending = BranchRequest.builder().sourceScheduleId(4L).build();
        when(requests.findPendingInvolvingUser(3L)).thenReturn(List.of(pending));
        assertThrows(BusinessException.class, () -> service.transfer(4L, 1L, 2L));
        when(requests.findPendingInvolvingUser(3L)).thenReturn(List.of());
        doThrow(new BusinessException("Đã duyệt nghỉ")).when(leave).assertNoLeave(3L, assignment.getDate());
        assertThrows(BusinessException.class, () -> service.transfer(4L, 1L, 2L));
        assertSame(home, assignment.getStore()); verifyNoInteractions(notifications);
    }

    @Test void overlappingAssignmentsAcrossBranchesBlockTransfer() {
        var other = UserSchedule.builder().id(6L).user(user).store(target).date(assignment.getDate())
                .shift(assignment.getShift()).status(ScheduleStatus.PENDING).build();
        when(schedules.findByUserIdAndDateBetweenOrderByDateAscShiftStartTimeAsc(any(), any(), any())).thenReturn(List.of(assignment, other));
        assertThrows(BusinessException.class, () -> service.transfer(4L, 1L, 2L));
        verifyNoInteractions(notifications);
    }
}
