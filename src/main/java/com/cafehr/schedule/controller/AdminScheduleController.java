package com.cafehr.schedule.controller;

import com.cafehr.common.dto.ApiResponse;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.schedule.dto.ShiftTemplateRequest;
import com.cafehr.schedule.entity.Shift;
import com.cafehr.schedule.repository.ShiftRepository;
import com.cafehr.schedule.repository.UserScheduleRepository;
import com.cafehr.staff.view.StaffViews;

import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import java.time.*;
import java.util.*;

@RestController @RequestMapping("/api/admin")
@RequiredArgsConstructor @PreAuthorize("hasRole('ADMIN')")
public class AdminScheduleController {
    private final ShiftRepository shifts;
    private final UserScheduleRepository schedules;

    public static Map<String, Object> template(Shift shift) {
        return StaffViews.row("id", shift.getId(), "name", shift.getName(),
                "startTime", shift.getStartTime(), "endTime", shift.getEndTime(),
                "breakMinutes", shift.getBreakMinutes(), "active", shift.isActive());
    }

    @GetMapping("/shifts") @Transactional(readOnly = true)
    public ApiResponse<List<Map<String, Object>>> shifts() {
        return ApiResponse.ok("Mẫu ca toàn chuỗi", shifts.findAll().stream()
                .sorted(Comparator.comparing(Shift::getStartTime)).map(AdminScheduleController::template).toList());
    }

    @PostMapping("/shifts") @Transactional
    public ApiResponse<Map<String, Object>> create(@Valid @RequestBody ShiftTemplateRequest body) {
        return save(new Shift(), body);
    }

    @PutMapping("/shifts/{id}") @Transactional
    public ApiResponse<Map<String, Object>> update(@PathVariable Long id, @Valid @RequestBody ShiftTemplateRequest body) {
        Shift shift = shifts.findById(id).orElseThrow(() -> new BusinessException("Không tìm thấy mẫu ca"));
        boolean changed = !shift.getName().equals(body.getName().trim())
                || !shift.getStartTime().equals(body.getStartTime()) || !shift.getEndTime().equals(body.getEndTime())
                || shift.getBreakMinutes() != body.getBreakMinutes();
        // Referenced templates are immutable: retain their original times for history and attendance.
        if (changed && schedules.existsByShiftId(id)) {
            shift.setActive(false);
            shift = new Shift();
        }
        return save(shift, body);
    }

    private ApiResponse<Map<String, Object>> save(Shift shift, ShiftTemplateRequest body) {
        long duration = Duration.between(body.getStartTime(), body.getEndTime()).toMinutes();
        if (duration < 0) duration += 1440;
        if (duration == 0 || body.getBreakMinutes() >= duration) {
            throw new BusinessException("Giờ kết thúc phải khác giờ bắt đầu; thời gian nghỉ phải nhỏ hơn độ dài ca");
        }
        shift.setName(body.getName().trim());
        shift.setStartTime(body.getStartTime());
        shift.setEndTime(body.getEndTime());
        shift.setBreakMinutes(body.getBreakMinutes());
        shift.setActive(body.isActive());
        return ApiResponse.ok("Đã lưu mẫu ca", template(shifts.save(shift)));
    }

    @GetMapping("/schedules") @Transactional(readOnly = true)
    public ApiResponse<List<Map<String, Object>>> schedules(@RequestParam LocalDate from,
            @RequestParam LocalDate to, @RequestParam(required = false) Long storeId) {
        if (from.isAfter(to) || from.plusMonths(3).isBefore(to)) throw new BusinessException("Chọn khoảng tối đa 3 tháng");
        return ApiResponse.ok("Lịch làm toàn chuỗi", schedules.findByDateBetweenOrderByDateAscShiftStartTimeAsc(from, to).stream()
                .filter(s -> storeId == null || s.getUser().getStore() != null && storeId.equals(s.getUser().getStore().getId()))
                .map(StaffViews::schedule).toList());
    }
}
