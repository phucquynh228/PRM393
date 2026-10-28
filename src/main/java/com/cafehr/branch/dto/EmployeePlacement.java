package com.cafehr.branch.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;

@Data
public class EmployeePlacement {
    public enum Action { TRANSFER, WAITING_TRANSFER, INACTIVE }
    @NotNull private Long userId;
    @NotNull private Action action;
    private Long targetStoreId;
    private boolean manager;
}
