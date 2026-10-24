package com.cafehr.service;

import com.cafehr.dto.BranchRequestCreate;
import com.cafehr.entity.*;
import com.cafehr.exception.BusinessException;
import com.cafehr.repository.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import java.time.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class StaffRequestServiceTest {
    @Mock BranchRequestRepository requests;
    @Mock UserScheduleRepository schedules;
    @Mock AttendanceRepository attendance;
    @Mock StaffWorkspaceService workspace;
    @Mock StaffNotificationService notifications;
    @Mock UserRepository users;
    @InjectMocks StaffRequestService service;
    Store store;
    User staff, peer;

    @BeforeEach void setup() {
        store = Store.builder().id(1L).name("Cafe Thủ Đức").build();
        staff = User.builder().id(3L).name("Nhân viên").role(Role.STAFF).store(store).build();
        peer = User.builder().id(4L).name("Đồng nghiệp").role(Role.STAFF).store(store).build();
        lenient().when(users.findLockedById(staff.getId())).thenReturn(Optional.of(staff));
        lenient().when(users.findLockedById(peer.getId())).thenReturn(Optional.of(peer));
    }
    UserSchedule shift(long id, User user, LocalDate date, int start, int end) {
        return UserSchedule.builder().id(id).user(user).date(date).status(ScheduleStatus.PENDING)
                .shift(Shift.builder().id(id).name("Ca " + id).startTime(LocalTime.of(start, 0)).endTime(LocalTime.of(end, 0)).build()).build();
    }
    BranchRequest request(long id, BranchRequestType type, LocalDate date) {
        return BranchRequest.builder().id(id).user(staff).type(type).startDate(date).endDate(date).reason("Lý do").build();
    }

    @Test void cancellationChecksOwner() {
        BranchRequest item = request(1, BranchRequestType.LEAVE, LocalDate.now().plusDays(1));
        when(requests.findLockedById(1L)).thenReturn(Optional.of(item));
        assertThrows(BusinessException.class, () -> service.cancel(peer.getId(), 1L));
        assertEquals(BranchRequestStatus.PENDING, item.getStatus());
    }
    @Test void pendingRequestCanBeCancelledButCannotBeApprovedAfterwards() {
        BranchRequest item = request(1, BranchRequestType.LEAVE, LocalDate.now().plusDays(1));
        when(requests.findLockedById(1L)).thenReturn(Optional.of(item));
        assertEquals("CANCELLED", service.cancel(staff.getId(), 1L).get("status"));
        assertThrows(BusinessException.class, () -> service.decide(1L, 1L, BranchRequestStatus.APPROVED, null));
    }
    @Test void otherBranchCannotApprove() {
        BranchRequest item = request(1, BranchRequestType.LEAVE, LocalDate.now().plusDays(1));
        when(requests.findLockedById(1L)).thenReturn(Optional.of(item));
        assertThrows(BusinessException.class, () -> service.decide(2L, 1L, BranchRequestStatus.APPROVED, null));
        verifyNoInteractions(notifications);
    }
    @Test void rejectionRequiresReasonAndCreatesNotification() {
        assertThrows(BusinessException.class, () -> service.decide(1L, 1L, BranchRequestStatus.REJECTED, " "));
        BranchRequest item = request(1, BranchRequestType.LEAVE, LocalDate.now().plusDays(1));
        when(requests.findLockedById(1L)).thenReturn(Optional.of(item));
        service.decide(1L, 1L, BranchRequestStatus.REJECTED, "Thiếu nhân sự");
        assertEquals("Thiếu nhân sự", item.getManagerNote());
        verify(notifications).send(eq(staff), anyString(), contains("Thiếu nhân sự"), eq("REQUEST"));
    }
    @Test void approvedLeaveUpdatesPublishedShifts() {
        LocalDate date = LocalDate.now().plusDays(2);
        UserSchedule shift = shift(10, staff, date, 7, 12);
        BranchRequest item = request(1, BranchRequestType.UNPAID_LEAVE, date);
        when(requests.findLockedById(1L)).thenReturn(Optional.of(item));
        when(schedules.findByUserIdAndDateBetweenAndPublishedTrueOrderByDateAscShiftStartTimeAsc(staff.getId(), date, date)).thenReturn(List.of(shift));
        when(schedules.findLockedById(10L)).thenReturn(Optional.of(shift));
        service.decide(1L, 1L, BranchRequestStatus.APPROVED, "Đồng ý");
        assertEquals(ScheduleStatus.ON_LEAVE, shift.getStatus());
        assertEquals(BranchRequestStatus.APPROVED, item.getStatus());
    }
    @Test void correctionCanCreateMissingRecordWithoutInventingGps() {
        LocalDate date = LocalDate.now().minusDays(1);
        UserSchedule shift = shift(10, staff, date, 7, 12);
        BranchRequest item = request(1, BranchRequestType.ATTENDANCE_CORRECTION, date);
        item.setSourceScheduleId(10L); item.setSourceShiftId(10L);
        item.setRequestedCheckIn(date.atTime(7, 10)); item.setRequestedCheckOut(date.atTime(11, 50));
        when(requests.findLockedById(1L)).thenReturn(Optional.of(item));
        when(schedules.findLockedById(10L)).thenReturn(Optional.of(shift));
        service.decide(1L, 1L, BranchRequestStatus.APPROVED, null);
        ArgumentCaptor<Attendance> saved = ArgumentCaptor.forClass(Attendance.class);
        verify(attendance).save(saved.capture());
        assertTrue(saved.getValue().isManuallyAdjusted());
        assertNull(saved.getValue().getCheckInLat());
        assertEquals(date.atTime(11, 50), saved.getValue().getCheckOutTime());
        assertEquals(ScheduleStatus.CHECKED_OUT, shift.getStatus());
    }
    @Test void correctionRejectsFutureTimes() {
        LocalDate date = LocalDate.now();
        UserSchedule shift = shift(10, staff, date, 7, 12);
        when(workspace.staff(staff.getId())).thenReturn(staff);
        when(schedules.findLockedById(10L)).thenReturn(Optional.of(shift));
        BranchRequestCreate body = new BranchRequestCreate();
        body.setType(BranchRequestType.ATTENDANCE_CORRECTION); body.setReason("Quên chấm công"); body.setSourceScheduleId(10L);
        body.setRequestedCheckIn(date.atStartOfDay()); body.setRequestedCheckOut(LocalDateTime.now().plusHours(1));
        assertThrows(BusinessException.class, () -> service.create(staff.getId(), body));
        verify(requests, never()).save(any());
    }
    @Test void swapTransfersBothSchedules() {
        LocalDate date = LocalDate.now().plusDays(2);
        UserSchedule source = shift(10, staff, date, 7, 12), target = shift(20, peer, date.plusDays(1), 12, 17);
        BranchRequest item = request(1, BranchRequestType.SHIFT_SWAP, date);
        item.setEndDate(target.getDate()); item.setSourceScheduleId(10L); item.setTargetScheduleId(20L);
        item.setSourceShiftId(10L); item.setTargetShiftId(20L); item.setTargetUserId(peer.getId());
        when(requests.findLockedById(1L)).thenReturn(Optional.of(item));
        when(schedules.findLockedById(10L)).thenReturn(Optional.of(source));
        when(schedules.findLockedById(20L)).thenReturn(Optional.of(target));
        service.decide(1L, 1L, BranchRequestStatus.APPROVED, null);
        assertEquals(peer, source.getUser()); assertEquals(staff, target.getUser());
        verify(notifications, times(2)).scheduleChanged(any(), anyString());
    }
    @Test void swapRejectsConflictingShift() {
        LocalDate date = LocalDate.now().plusDays(2);
        UserSchedule source = shift(10, staff, date, 7, 12), target = shift(20, peer, date, 12, 17);
        UserSchedule conflict = shift(30, staff, date, 14, 19);
        when(workspace.staff(staff.getId())).thenReturn(staff);
        when(schedules.findLockedById(10L)).thenReturn(Optional.of(source));
        when(schedules.findLockedById(20L)).thenReturn(Optional.of(target));
        conflict.setPublished(false);
        when(schedules.findByUserIdAndDateBetweenOrderByDateAscShiftStartTimeAsc(
                staff.getId(), date.minusDays(1), date.plusDays(1))).thenReturn(List.of(conflict));
        BranchRequestCreate body = new BranchRequestCreate(); body.setType(BranchRequestType.SHIFT_SWAP);
        body.setReason("Đổi ca"); body.setSourceScheduleId(10L); body.setTargetScheduleId(20L);
        assertThrows(BusinessException.class, () -> service.create(staff.getId(), body));
        verify(requests, never()).save(any());
    }
}
