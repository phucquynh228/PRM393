package com.cafehr.branch.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import lombok.Data;
import java.util.List;

@Data
public class BranchClosureRequest {
    @NotBlank @Size(max = 500) private String reason;
    @NotNull @Valid private List<@NotNull @Valid EmployeePlacement> placements;
}
