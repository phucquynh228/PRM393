package com.cafehr.branch.controller;

import com.cafehr.attendance.repository.AttendanceRepository;
import com.cafehr.branch.entity.Store;
import com.cafehr.branch.repository.StoreRepository;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.notification.service.StaffNotificationService;
import com.cafehr.schedule.dto.ManagerScheduleRequest;
import com.cafehr.schedule.entity.ScheduleStatus;
import com.cafehr.schedule.entity.Shift;
import com.cafehr.schedule.entity.UserSchedule;
import com.cafehr.schedule.repository.ShiftRepository;
import com.cafehr.schedule.repository.UserScheduleRepository;
import com.cafehr.schedule.service.ScheduleRules;
import com.cafehr.staff.repository.BranchRequestRepository;
import com.cafehr.staff.service.StaffRequestService;
import com.cafehr.user.entity.Role;
import com.cafehr.user.entity.User;
import com.cafehr.user.repository.UserRepository;

import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.security.crypto.password.PasswordEncoder;
import java.time.*;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class BranchScheduleControllerTest {
    @Mock UserRepository userRepository;
    @Mock StoreRepository storeRepository;
    @Mock ShiftRepository shiftRepository;
    @Mock UserScheduleRepository scheduleRepository;
    @Mock AttendanceRepository attendanceRepository;
    @Mock BranchRequestRepository branchRequestRepository;
    @Mock PasswordEncoder passwordEncoder;
    @Mock StaffRequestService staffRequestService;
    @Mock StaffNotificationService staffNotifications;
    @Mock ScheduleRules scheduleRules;
    @InjectMocks BranchManagerController controller;
    Store store;
    User staff;
    MockHttpServletRequest request;
    LocalDate day = LocalDate.now().plusDays(5);
    @BeforeEach void setup() {
        store = Store.builder().id(1L).name("Chi nhánh 1").build();
        User manager = User.builder().id(2L).role(Role.MANAGER).store(store).build();
        staff = User.builder().id(3L).role(Role.STAFF).store(store).build();
        request = new MockHttpServletRequest(); request.setAttribute("userId", 2L);
        when(userRepository.findById(2L)).thenReturn(Optional.of(manager));
        when(storeRepository.findById(1L)).thenReturn(Optional.of(store));
    }
    UserSchedule draft(long id) {
        return UserSchedule.builder().id(id).user(staff).published(false).date(day).status(ScheduleStatus.PENDING)
                .shift(Shift.builder().id(1L).name("Ca sáng").startTime(LocalTime.of(8, 0)).endTime(LocalTime.of(12, 0)).build()).build();
    }
    @Test void invalidDraftPreventsPublishingEntireRange() {
        UserSchedule first = draft(1), second = draft(2);
        when(scheduleRepository.findByUserStoreIdAndDateBetweenOrderByDateAscShiftStartTimeAsc(1L, day, day)).thenReturn(List.of(first, second));
        when(userRepository.findLockedById(3L)).thenReturn(Optional.of(staff));
        doNothing().when(scheduleRules).validate(first);
        doThrow(new BusinessException("Trùng giờ")).when(scheduleRules).validate(second);
        assertThrows(BusinessException.class, () -> controller.publishRange(request, day, day));
        assertFalse(first.isPublished()); assertFalse(second.isPublished());
        verifyNoInteractions(staffNotifications);
    }
    @Test void validRangePublishesAndNotifies() {
        UserSchedule first = draft(1);
        when(scheduleRepository.findByUserStoreIdAndDateBetweenOrderByDateAscShiftStartTimeAsc(1L, day, day)).thenReturn(List.of(first));
        when(userRepository.findLockedById(3L)).thenReturn(Optional.of(staff));
        controller.publishRange(request, day, day);
        assertTrue(first.isPublished()); verify(staffNotifications).scheduleChanged(eq(first), anyString());
    }
    @Test void managerCannotAssignStaffFromAnotherBranch() {
        staff.setStore(Store.builder().id(9L).build());
        when(userRepository.findLockedById(3L)).thenReturn(Optional.of(staff));
        ManagerScheduleRequest body = new ManagerScheduleRequest(); body.setUserId(3L); body.setShiftId(1L); body.setDate(day);
        assertThrows(BusinessException.class, () -> controller.createSchedule(request, body));
        verifyNoInteractions(shiftRepository, staffNotifications, scheduleRules);
        verify(scheduleRepository, never()).save(any());
    }
}
