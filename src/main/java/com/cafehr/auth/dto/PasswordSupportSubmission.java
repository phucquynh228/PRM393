package com.cafehr.auth.dto;

import jakarta.validation.constraints.*;

public record PasswordSupportSubmission(
        @NotBlank @Pattern(regexp = "[0-9]{10,15}", message = "Số điện thoại gồm 10–15 chữ số") String phone,
        @NotBlank @Size(max = 100) String name,
        @Size(max = 500) String note) {}
