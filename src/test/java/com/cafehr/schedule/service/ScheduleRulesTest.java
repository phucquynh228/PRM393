package com.cafehr.schedule.service;

import com.cafehr.common.exception.BusinessException;
import com.cafehr.schedule.entity.ScheduleStatus;
import com.cafehr.schedule.entity.Shift;
import com.cafehr.schedule.entity.UserSchedule;
import com.cafehr.schedule.repository.UserScheduleRepository;
import com.cafehr.user.entity.Role;
import com.cafehr.user.entity.User;

import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import java.time.*;
import java.util.List;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class ScheduleRulesTest {
    @Mock UserScheduleRepository schedules;
    @InjectMocks ScheduleRules rules;
    final LocalDate day = LocalDate.now().plusDays(5);
    final User staff = User.builder().id(1L).role(Role.STAFF).build();
    UserSchedule shift(long id, LocalDate date, int start, int end) {
        return UserSchedule.builder().id(id).user(staff).date(date).status(ScheduleStatus.PENDING)
                .published(false).shift(Shift.builder().id(id).name("Ca")
                        .startTime(LocalTime.of(start, 0)).endTime(LocalTime.of(end, 0)).build()).build();
    }
    void existing(UserSchedule... items) {
        when(schedules.findByUserIdAndDateBetweenOrderByDateAscShiftStartTimeAsc(anyLong(), any(), any()))
                .thenReturn(List.of(items));
    }
    @Test void differentTemplatesStillOverlapIncludingDrafts() {
        existing(shift(2, day, 8, 14));
        assertThrows(BusinessException.class, () -> rules.validate(shift(1, day, 12, 18)));
    }
    @Test void overnightShiftOverlapsFollowingMorning() {
        existing(shift(2, day.minusDays(1), 22, 7));
        assertThrows(BusinessException.class, () -> rules.validate(shift(1, day, 6, 12)));
    }
    @Test void overnightShiftOverlapsNextDaySchedule() {
        existing(shift(2, day.plusDays(1), 6, 12));
        assertThrows(BusinessException.class, () -> rules.validate(shift(1, day, 22, 7)));
    }
    @Test void adjoiningShiftsAndCurrentRecordDoNotConflict() {
        UserSchedule incoming = shift(1, day, 8, 12);
        existing(incoming, shift(2, day, 12, 16));
        assertDoesNotThrow(() -> rules.validate(incoming));
    }
    @Test void leaveScheduleDoesNotBlockAssignment() {
        UserSchedule leave = shift(2, day, 8, 16);
        leave.setStatus(ScheduleStatus.ON_LEAVE);
        existing(leave);
        assertDoesNotThrow(() -> rules.validate(shift(1, day, 8, 16)));
    }
    @Test void inactiveTemplateCannotBeAssignedOrPublished() {
        UserSchedule schedule = shift(1, day, 8, 16);
        schedule.getShift().setActive(false);
        assertThrows(BusinessException.class, () -> rules.validate(schedule));
        verifyNoInteractions(schedules);
    }
    @Test void startedShiftCannotBePublished() {
        assertThrows(BusinessException.class, () -> rules.validate(shift(1, day.minusDays(7), 8, 16)));
    }
}
