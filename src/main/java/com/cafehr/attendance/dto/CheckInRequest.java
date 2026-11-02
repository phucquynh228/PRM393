package com.cafehr.attendance.dto;

import jakarta.validation.constraints.NotNull;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * DTO cho request check-in chấm công.
 * Client gửi tọa độ GPS hiện tại.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class CheckInRequest {

    @NotNull(message = "Latitude không được để trống")
    private Double lat;

    @NotNull(message = "Longitude không được để trống")
    private Double lng;

    /**
     * ID của schedule cần check-in (optional).
     * Nếu null, hệ thống tự tìm schedule hôm nay của user.
     */
    private Long scheduleId;
}
