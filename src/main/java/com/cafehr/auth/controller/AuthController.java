package com.cafehr.auth.controller;

import com.cafehr.auth.dto.GoogleLinkRequest;
import com.cafehr.auth.dto.GoogleLoginRequest;
import com.cafehr.auth.dto.GoogleLoginResponse;
import com.cafehr.auth.dto.LoginRequest;
import com.cafehr.auth.dto.LoginResponse;
import com.cafehr.auth.service.AuthService;
import com.cafehr.auth.service.GoogleAuthService;
import com.cafehr.common.dto.ApiResponse;

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
    private final GoogleAuthService googleAuthService;

    @GetMapping("/google/config")
    public ApiResponse<java.util.Map<String, Object>> googleConfig() {
        return ApiResponse.ok(googleAuthService.configuration());
    }

    @PostMapping("/google")
    public ResponseEntity<ApiResponse<GoogleLoginResponse>> google(@Valid @RequestBody GoogleLoginRequest request) {
        return ResponseEntity.ok(ApiResponse.ok("Xác thực Google", googleAuthService.login(request)));
    }

    @PostMapping("/google/link")
    public ResponseEntity<ApiResponse<LoginResponse>> linkGoogle(@Valid @RequestBody GoogleLinkRequest request) {
        return ResponseEntity.ok(ApiResponse.ok("Đã liên kết Google", googleAuthService.link(request)));
    }

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
