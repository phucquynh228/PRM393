package com.cafehr.controller;

import com.cafehr.dto.ApiResponse;
import com.cafehr.dto.LoginRequest;
import com.cafehr.dto.LoginResponse;
import com.cafehr.service.AuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

/**
 * REST Controller xử lý Authentication.
 */
@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;

    /**
     * POST /api/auth/login
     * Đăng nhập với phone, password, deviceId.
     */
    @PostMapping("/login")
    public ResponseEntity<ApiResponse<LoginResponse>> login(@Valid @RequestBody LoginRequest request) {
        LoginResponse response = authService.login(request);
        return ResponseEntity.ok(ApiResponse.ok("Đăng nhập thành công", response));
    }

    /**
     * POST /api/auth/reset-device/{userId}
     * Reset device binding cho user.
     */
    @PostMapping("/reset-device/{userId}")
    public ResponseEntity<ApiResponse<Void>> resetDevice(@PathVariable Long userId) {
        authService.resetDevice(userId);
        return ResponseEntity.ok(ApiResponse.ok("Reset thiết bị thành công", null));
    }
}
