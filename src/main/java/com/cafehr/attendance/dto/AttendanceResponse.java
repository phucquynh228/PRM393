package com.cafehr.attendance.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * DTO response cho bản ghi chấm công.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AttendanceResponse {

    private Long id;
    private Long userId;
    private String userName;
    private Long scheduleId;
    private String shiftName;
    private LocalDateTime checkInTime;
    private LocalDateTime checkOutTime;
    private Double checkInLat;
    private Double checkInLng;
    private String status;
}
