package com.cafehr.admin.controller;

import com.cafehr.auth.dto.*;
import com.cafehr.auth.entity.PasswordSupportRequest.Status;
import com.cafehr.auth.service.PasswordSupportService;
import com.cafehr.common.dto.ApiResponse;
import com.cafehr.common.exception.BusinessException;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController @RequiredArgsConstructor
@RequestMapping("/api/admin/password-support")
@PreAuthorize("hasRole('ADMIN')")
public class AdminPasswordSupportController {
    private final PasswordSupportService support;

    @GetMapping
    public ResponseEntity<ApiResponse<List<PasswordSupportView>>> list(@RequestParam(defaultValue = "PENDING") String status) {
        Status filter;
        try { filter = Status.valueOf(status); }
        catch (IllegalArgumentException ex) { throw new BusinessException("Trạng thái yêu cầu không hợp lệ"); }
        return ResponseEntity.ok().header("Cache-Control", "no-store").body(ApiResponse.ok(support.list(filter)));
    }

    @PutMapping("/{id}")
    public ResponseEntity<ApiResponse<PasswordSupportView>> decide(@PathVariable Long id,
            Authentication admin, @Valid @RequestBody PasswordSupportDecision body) {
        return ResponseEntity.ok().header("Cache-Control", "no-store")
                .body(ApiResponse.ok("Đã xử lý yêu cầu hỗ trợ", support.decide(id, admin.getName(), body)));
    }
}
