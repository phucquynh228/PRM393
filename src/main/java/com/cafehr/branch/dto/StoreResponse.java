package com.cafehr.branch.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class StoreResponse {
    private Long id;
    private String code;
    private String name;
    private Double latitude;
    private Double longitude;
    private Integer allowedRadius;
    private Integer maxStaff;
    private String status;
    private Long managerId;
    private String managerName;
    private String managerPhone;
    private long currentStaffCount;
}
