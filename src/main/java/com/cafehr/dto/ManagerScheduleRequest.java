package com.cafehr.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDate;

@Data
public class ManagerScheduleRequest {

    @NotNull
    private Long userId;

    @NotNull
    private Long shiftId;

    @NotNull
    private LocalDate date;

    private boolean published;
}
