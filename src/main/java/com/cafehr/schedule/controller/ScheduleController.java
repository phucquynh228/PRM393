package com.cafehr.schedule.controller;

import com.cafehr.common.dto.ApiResponse;
import com.cafehr.schedule.dto.ScheduleResponse;
import com.cafehr.schedule.entity.UserSchedule;
import com.cafehr.schedule.repository.UserScheduleRepository;

import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

/**
 * REST Controller xử lý lịch làm việc (/api/schedules).
 */
@RestController
@RequestMapping("/api/schedules")
@RequiredArgsConstructor
public class ScheduleController {

    private final UserScheduleRepository userScheduleRepository;

    /**
     * GET /api/schedules/today
     * Lấy danh sách ca làm việc hôm nay của user hiện tại.
     */
    @GetMapping("/today")
    public ResponseEntity<ApiResponse<List<ScheduleResponse>>> getTodaySchedules(HttpServletRequest request) {
        Long userId = (Long) request.getAttribute("userId");
        if (userId == null) {
            throw new RuntimeException("Không thể xác định user từ token");
        }

        List<UserSchedule> schedules = userScheduleRepository
                .findByUserIdAndDateAndPublishedTrue(userId, LocalDate.now());

        List<ScheduleResponse> response = schedules.stream().map(s -> ScheduleResponse.builder()
                .id(s.getId())
                .scheduleId(s.getId())
                .shiftName(s.getShift().getName())
                .startTime(s.getShift().getStartTime().toString())
                .endTime(s.getShift().getEndTime().toString())
                .status(s.getStatus().name())
                .build()
        ).collect(Collectors.toList());

        return ResponseEntity.ok(ApiResponse.ok("Lịch làm việc hôm nay", response));
    }
}
