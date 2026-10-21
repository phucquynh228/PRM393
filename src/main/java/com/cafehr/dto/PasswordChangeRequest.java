package com.cafehr.dto;

import jakarta.validation.constraints.*;
import lombok.Data;

@Data
public class PasswordChangeRequest {
    @NotBlank
    private String currentPassword;
    @NotBlank @Size(min = 6, max = 72)
    private String newPassword;
}
