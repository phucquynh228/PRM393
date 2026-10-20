package com.cafehr.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class ManagerStaffRequest {

    @NotBlank
    @Size(max = 100)
    private String name;

    @NotBlank
    @Pattern(regexp = "^[0-9+() -]{8,15}$")
    private String phone;

    @Size(min = 6, max = 100)
    private String password;
}
