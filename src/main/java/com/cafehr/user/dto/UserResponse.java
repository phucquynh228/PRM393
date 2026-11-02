package com.cafehr.user.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserResponse {
    private Long id;
    private String name;
    private String phone;
    private String role;
    private Long storeId;
    private String storeName;
    private String deviceId;
    private String employmentStatus;
}
