package com.cafehr.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DashboardSummaryResponse {
    private long totalStores;
    private long totalUsers;
    private long totalShifts;
    private long todayAttendanceCount;
}
