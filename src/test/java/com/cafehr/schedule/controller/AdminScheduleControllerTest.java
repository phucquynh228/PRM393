package com.cafehr.schedule.controller;

import com.cafehr.common.exception.BusinessException;
import com.cafehr.schedule.dto.ShiftTemplateRequest;
import com.cafehr.schedule.entity.Shift;
import com.cafehr.schedule.repository.ShiftRepository;
import com.cafehr.schedule.repository.UserScheduleRepository;

import org.junit.jupiter.api.*;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.*;
import org.mockito.junit.jupiter.MockitoExtension;
import java.time.LocalTime;
import java.util.Optional;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AdminScheduleControllerTest {
    @Mock ShiftRepository shifts;
    @Mock UserScheduleRepository schedules;
    @InjectMocks AdminScheduleController controller;

    ShiftTemplateRequest body() {
        ShiftTemplateRequest body = new ShiftTemplateRequest();
        body.setName("Ca sáng"); body.setStartTime(LocalTime.of(8, 0)); body.setEndTime(LocalTime.of(16, 0));
        body.setBreakMinutes(30); return body;
    }
    @Test void editingReferencedTemplatePreservesOriginalHours() {
        Shift old = new Shift(1L, "Ca sáng", LocalTime.of(7, 0), LocalTime.of(12, 0));
        when(shifts.findById(1L)).thenReturn(Optional.of(old));
        when(schedules.existsByShiftId(1L)).thenReturn(true);
        when(shifts.save(any())).thenAnswer(i -> i.getArgument(0));
        controller.update(1L, body());
        assertFalse(old.isActive());
        assertEquals(LocalTime.of(7, 0), old.getStartTime());
        ArgumentCaptor<Shift> saved = ArgumentCaptor.forClass(Shift.class);
        verify(shifts).save(saved.capture());
        assertNotSame(old, saved.getValue());
        assertEquals(LocalTime.of(8, 0), saved.getValue().getStartTime());
        assertTrue(saved.getValue().isActive());
    }
    @Test void disablingTemplateKeepsItsIdAndTimes() {
        Shift old = new Shift(1L, "Ca sáng", LocalTime.of(8, 0), LocalTime.of(16, 0)); old.setBreakMinutes(30);
        when(shifts.findById(1L)).thenReturn(Optional.of(old));
        when(shifts.save(any())).thenAnswer(i -> i.getArgument(0));
        ShiftTemplateRequest body = body(); body.setActive(false);
        controller.update(1L, body);
        verify(shifts).save(old); verifyNoInteractions(schedules);
        assertFalse(old.isActive()); assertEquals(1L, old.getId());
    }
    @Test void breakMustFitInsideOvernightShift() {
        ShiftTemplateRequest body = body(); body.setStartTime(LocalTime.of(22, 0)); body.setEndTime(LocalTime.of(2, 0));
        body.setBreakMinutes(240);
        assertThrows(BusinessException.class, () -> controller.create(body));
        verifyNoInteractions(shifts);
    }
}
