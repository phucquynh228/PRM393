package com.cafehr.schedule.entity;

import jakarta.persistence.*;
import lombok.*;

@Embeddable @Getter @Setter @NoArgsConstructor @AllArgsConstructor
public class BranchShiftPlan {
    private Long shiftId;
    @Column(nullable = false)
    private int requiredStaff;
}
