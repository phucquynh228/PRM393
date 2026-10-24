package com.cafehr.staff.dto;

import jakarta.validation.constraints.*;
import lombok.Data;

@Data
public class StaffProfileUpdate {
    @NotBlank @Size(max = 100)
    private String name;
    @Email @Size(max = 150)
    private String email;
    @Pattern(regexp = "^$|[0-9+ ()-]{9,20}$")
    private String emergencyContact;
    @Size(max = 255)
    private String address;
}
