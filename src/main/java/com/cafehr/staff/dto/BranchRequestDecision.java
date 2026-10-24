package com.cafehr.staff.dto;

import com.cafehr.staff.entity.BranchRequestStatus;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class BranchRequestDecision {

    @NotNull
    private BranchRequestStatus status;

    private String managerNote;
}
