package com.cafehr.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * DTO cho request check-out chấm công.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class CheckOutRequest {

    /**
     * ID của bản ghi attendance cần check-out.
     */
    private Long attendanceId;
}
