package com.cafehr.dto;

import com.cafehr.entity.BranchRequestStatus;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class BranchRequestDecision {

    @NotNull
    private BranchRequestStatus status;

    private String managerNote;
}
