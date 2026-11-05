package com.cafehr.auth.controller;

import com.cafehr.auth.dto.PasswordSupportSubmission;
import com.cafehr.auth.service.PasswordSupportService;
import com.cafehr.common.dto.ApiResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController @RequiredArgsConstructor
@RequestMapping("/api/auth/password-support")
public class PasswordSupportController {
    private final PasswordSupportService support;

    @PostMapping
    public ResponseEntity<ApiResponse<Void>> submit(@Valid @RequestBody PasswordSupportSubmission body) {
        support.submit(body);
        return ResponseEntity.accepted().header("Cache-Control", "no-store")
                .body(ApiResponse.ok(PasswordSupportService.ACKNOWLEDGEMENT, null));
    }
}
