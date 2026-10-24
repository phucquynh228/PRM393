package com.cafehr.schedule.dto;

import jakarta.validation.constraints.*;
import lombok.Data;
import java.time.LocalTime;

@Data
public class ShiftTemplateRequest {
    @NotBlank @Size(max = 100)
    private String name;
    @NotNull
    private LocalTime startTime;
    @NotNull
    private LocalTime endTime;
    @Min(0) @Max(1439)
    private int breakMinutes;
    private boolean active = true;
}
