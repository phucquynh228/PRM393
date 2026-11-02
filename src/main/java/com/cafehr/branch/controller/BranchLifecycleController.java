package com.cafehr.branch.controller;

import com.cafehr.branch.dto.*;
import com.cafehr.branch.service.BranchLifecycleService;
import com.cafehr.common.dto.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController @RequestMapping("/api/admin") @RequiredArgsConstructor @PreAuthorize("hasRole('ADMIN')")
public class BranchLifecycleController {
    private final BranchLifecycleService service;
    @GetMapping("/stores/{id}/closure-preview")
    public ApiResponse<Map<String, Object>> preview(@PathVariable Long id) { return ApiResponse.ok("Kiểm tra ngừng hoạt động", service.preview(id)); }
    @PostMapping("/stores/{id}/close")
    public ApiResponse<Map<String, Object>> close(@PathVariable Long id, @Valid @RequestBody BranchClosureRequest body) {
        return ApiResponse.ok("Đã ngừng hoạt động và xử lý nhân sự", service.close(id, body));
    }
    @PutMapping("/users/{id}/placement")
    public ApiResponse<Map<String, Object>> place(@PathVariable Long id, @Valid @RequestBody EmployeePlacement body) {
        return ApiResponse.ok("Đã cập nhật bố trí nhân sự", service.place(id, body));
    }
}
