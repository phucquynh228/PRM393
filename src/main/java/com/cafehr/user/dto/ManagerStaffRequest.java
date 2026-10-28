package com.cafehr.user.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.Data;
import com.cafehr.schedule.entity.FixedRosterEntry;

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

    @jakarta.validation.constraints.Size(max = 21)
    private java.util.List<@jakarta.validation.constraints.NotNull @jakarta.validation.Valid FixedRosterEntry> fixedRoster;
}
