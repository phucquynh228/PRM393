package com.cafehr.controller;

import com.cafehr.dto.*;
import com.cafehr.service.AttendanceService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * REST Controller xử lý chấm công (check-in / check-out / history).
 */
@RestController
@RequestMapping("/api/attendance")
@RequiredArgsConstructor
public class AttendanceController {

    private final AttendanceService attendanceService;

    /**
     * POST /api/attendance/check-in
     * Chấm công vào ca — gửi tọa độ GPS.
     * userId được lấy tự động từ JWT token.
     */
    @PostMapping("/check-in")
    public ResponseEntity<ApiResponse<AttendanceResponse>> checkIn(
            @Valid @RequestBody CheckInRequest request,
            HttpServletRequest httpRequest
    ) {
        Long userId = getUserIdFromRequest(httpRequest);
        AttendanceResponse response = attendanceService.checkIn(userId, request);
        return ResponseEntity.ok(ApiResponse.ok("Check-in thành công", response));
    }

    /**
     * POST /api/attendance/check-out/{attendanceId}
     * Chấm công ra ca.
     */
    @PostMapping("/check-out/{attendanceId}")
    public ResponseEntity<ApiResponse<AttendanceResponse>> checkOut(
            @PathVariable Long attendanceId,
            HttpServletRequest httpRequest
    ) {
        Long userId = getUserIdFromRequest(httpRequest);
        AttendanceResponse response = attendanceService.checkOut(userId, attendanceId);
        return ResponseEntity.ok(ApiResponse.ok("Check-out thành công", response));
    }

    /**
     * GET /api/attendance/history
     * Lấy lịch sử chấm công của user hiện tại.
     */
    @GetMapping("/history")
    public ResponseEntity<ApiResponse<List<AttendanceResponse>>> getHistory(
            HttpServletRequest httpRequest
    ) {
        Long userId = getUserIdFromRequest(httpRequest);
        List<AttendanceResponse> history = attendanceService.getHistory(userId);
        return ResponseEntity.ok(ApiResponse.ok("Lịch sử chấm công", history));
    }

    /**
     * Lấy userId từ request attribute (được set bởi JwtAuthenticationFilter).
     */
    private Long getUserIdFromRequest(HttpServletRequest request) {
        Object userId = request.getAttribute("userId");
        if (userId == null) {
            throw new RuntimeException("Không thể xác định user từ token");
        }
        return (Long) userId;
    }
}
