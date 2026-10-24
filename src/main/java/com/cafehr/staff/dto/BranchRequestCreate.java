package com.cafehr.staff.dto;

import com.cafehr.staff.entity.BranchRequestType;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Data
public class BranchRequestCreate {

    @NotNull
    private BranchRequestType type;

    @NotNull
    private LocalDate startDate;

    @NotNull
    private LocalDate endDate;

    @NotBlank
    private String reason;

    private Long sourceScheduleId;
    private Long targetScheduleId;
    private LocalDateTime requestedCheckIn;
    private LocalDateTime requestedCheckOut;
}
