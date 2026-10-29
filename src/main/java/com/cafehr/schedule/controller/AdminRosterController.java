package com.cafehr.schedule.controller;

import com.cafehr.common.dto.ApiResponse;
import com.cafehr.schedule.service.AdminRosterService;
import com.cafehr.schedule.service.FixedRosterService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.*;

@RestController @RequestMapping("/api/admin")
@RequiredArgsConstructor @PreAuthorize("hasRole('ADMIN')")
public class AdminRosterController {
    private final FixedRosterService roster;
    private final AdminRosterService transfers;

    public record Transfer(@NotNull @Positive Long sourceStoreId, @NotNull @Positive Long targetStoreId) {}

    @GetMapping("/roster/settings")
    public ApiResponse<List<Map<String, Object>>> settings(@RequestParam(required = false) Long storeId) {
        return ApiResponse.ok("Định mức ca các chi nhánh", roster.adminSettings(storeId));
    }

    @PutMapping("/schedules/{id}/transfer")
    public ApiResponse<Map<String, Object>> transfer(@PathVariable Long id, @Valid @RequestBody Transfer body) {
        return ApiResponse.ok("Đã điều chuyển ca làm", transfers.transfer(id, body.sourceStoreId(), body.targetStoreId()));
    }
}
