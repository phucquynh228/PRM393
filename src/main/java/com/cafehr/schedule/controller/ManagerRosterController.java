package com.cafehr.schedule.controller;

import com.cafehr.common.dto.ApiResponse;
import com.cafehr.common.exception.BusinessException;
import com.cafehr.schedule.dto.RosterRequests;
import com.cafehr.schedule.service.FixedRosterService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController @RequestMapping("/api/manager") @RequiredArgsConstructor @PreAuthorize("hasRole('MANAGER')")
public class ManagerRosterController {
    private final FixedRosterService roster;
    private Long manager(HttpServletRequest request) {
        if (request.getAttribute("userId") instanceof Long id) return id;
        throw new BusinessException("Không thể xác định tài khoản quản lý");
    }
    @GetMapping("/roster/settings")
    public ApiResponse<List<Map<String, Object>>> settings(HttpServletRequest request) {
        return ApiResponse.ok(roster.settings(manager(request)));
    }
    @PutMapping("/roster/settings")
    public ApiResponse<List<Map<String, Object>>> save(HttpServletRequest request, @Valid @RequestBody RosterRequests.Settings body) {
        return ApiResponse.ok("Đã lưu mẫu ca và định mức nhân sự", roster.saveSettings(manager(request), body));
    }
    @PostMapping("/schedules/batch")
    public ApiResponse<Map<String, Object>> assign(HttpServletRequest request, @Valid @RequestBody RosterRequests.Batch body) {
        return ApiResponse.ok("Đã thêm nhân sự vào lịch nháp", roster.assign(manager(request), body));
    }
    @PostMapping("/schedules/generate-week")
    public ApiResponse<Map<String, Object>> generate(HttpServletRequest request, @Valid @RequestBody RosterRequests.GenerateWeek body) {
        return ApiResponse.ok("Đã tạo lịch nháp theo ca mặc định", roster.generate(manager(request), body.weekStart()));
    }
}
