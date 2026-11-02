package com.cafehr.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class GoogleLoginRequest {
    @NotBlank @Size(max = 10000)
    @lombok.ToString.Exclude
    private String idToken;
    @NotBlank @Size(max = 255)
    private String deviceId;
}
