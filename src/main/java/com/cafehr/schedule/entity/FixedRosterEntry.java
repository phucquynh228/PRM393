package com.cafehr.schedule.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.*;
import lombok.*;

@Embeddable @Getter @Setter @NoArgsConstructor @AllArgsConstructor @EqualsAndHashCode
public class FixedRosterEntry {
    @Min(1) @Max(7) @Column(name = "day_of_week", nullable = false)
    private int dayOfWeek;
    @NotNull @Enumerated(EnumType.STRING) @Column(nullable = false, length = 20)
    private ShiftSlot slot;
}
