package com.cafehr.controller;

import com.cafehr.dto.*;
import com.cafehr.service.StaffWorkspaceService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDate;
import java.util.Map;

@RestController @RequestMapping("/api/staff") @RequiredArgsConstructor
@PreAuthorize("hasRole('STAFF')")
public class StaffController {
    private final StaffWorkspaceService service;

    @GetMapping("/workspace")
    public ApiResponse<Map<String, Object>> workspace(HttpServletRequest request,
            @RequestParam LocalDate from, @RequestParam LocalDate to) {
        return ApiResponse.ok("Không gian nhân viên", service.workspace(id(request), from, to));
    }

    @GetMapping("/request-options")
    public ApiResponse<Map<String, Object>> options(HttpServletRequest request) {
        return ApiResponse.ok("Ca làm có thể yêu cầu", service.options(id(request)));
    }

    @PutMapping("/profile")
    public ApiResponse<Map<String, Object>> profile(HttpServletRequest request, @Valid @RequestBody StaffProfileUpdate body) {
        return ApiResponse.ok("Đã cập nhật hồ sơ", service.updateProfile(id(request), body));
    }

    @PutMapping("/password")
    public ApiResponse<Void> password(HttpServletRequest request, @Valid @RequestBody PasswordChangeRequest body) {
        service.changePassword(id(request), body);
        return ApiResponse.ok("Đã đổi mật khẩu", null);
    }

    @PutMapping("/notifications/read-all")
    public ApiResponse<Void> readAll(HttpServletRequest request) {
        service.markAllRead(id(request));
        return ApiResponse.ok("Đã đọc tất cả thông báo", null);
    }

    @PutMapping("/notifications/{id}/read")
    public ApiResponse<Void> read(HttpServletRequest request, @PathVariable Long id) {
        service.markRead(id(request), id);
        return ApiResponse.ok("Đã đọc thông báo", null);
    }

    private Long id(HttpServletRequest request) { return (Long) request.getAttribute("userId"); }
}
