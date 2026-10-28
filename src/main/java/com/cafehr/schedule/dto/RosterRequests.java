package com.cafehr.schedule.dto;

import com.cafehr.schedule.entity.ShiftSlot;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.time.LocalDate;
import java.util.List;

public final class RosterRequests {
    private RosterRequests() {}
    public record SlotPlan(@NotNull ShiftSlot slot, Long shiftId, @Min(0) @Max(200) int requiredStaff) {}
    public record Settings(@NotNull @Size(min = 3, max = 3) List<@NotNull @Valid SlotPlan> slots) {}
    public record Batch(@NotNull LocalDate date, @NotNull ShiftSlot slot,
                        @NotEmpty @Size(max = 200) List<@NotNull @Positive Long> userIds) {}
    public record GenerateWeek(@NotNull LocalDate weekStart) {}
}
